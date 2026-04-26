defmodule AWS.Client do
  @moduledoc """
  Shared SigV4 request dispatcher for every per-service
  `*.Operation` struct.

  Owns the parts that are identical across EventBridge, Logs,
  Organizations, Identity Center, IAM, S3, and STS:

    * SigV4 signing via `AWS.Signer.sign/5`,
    * HTTP dispatch via `AWS.HTTP` (buffered, stream-upload, or
      stream-download depending on struct fields),
    * status-code branching into `{:ok, resp}` for 2xx,
      `{:error, {:http_error, status, body}}` otherwise, and
      `{:error, reason}` on transport failure,
    * credential / endpoint / sandbox resolution driven by a per-service
      opts namespace (`:s3`, `:iam`, `:events`, `:logs`,
      `:organizations`, `:identity_center`).

  Callers build a populated Operation struct in their service facade
  (`AWS.EventBridge`, `AWS.S3`, …) and hand it to `execute/1`. The
  struct is the whole contract between facade and dispatcher: body
  is already encoded, headers are already populated, URL is already
  composed.

  Per-service facades contribute only the parts that genuinely differ
  across AWS protocols: body encoding (JSON vs form-urlencoded vs
  passthrough), request headers (`X-Amz-Target` for JSON 1.1, `Action`
  in body for Query, per-operation for REST/XML), URL composition
  (virtual-hosted addressing is S3-only), and response body decoding.
  """

  alias AWS.{Config, HTTP, Signer}

  @type method :: :get | :post | :put | :delete | :head
  @type header :: {String.t(), String.t()}
  @type body :: iodata | Enumerable.t()

  @type response :: %{
          status_code: non_neg_integer,
          headers: [header],
          body: binary
        }

  @type stream_response :: %{
          status_code: non_neg_integer,
          headers: [header],
          body_stream: Enumerable.t()
        }

  @doc """
  Issues a SigV4-signed HTTP request from a populated Operation
  struct.

  The argument can be any struct carrying the SigV4 fields — in
  practice one of the per-service Operation structs
  (`AWS.EventBridge.Operation`, `AWS.Logs.Operation`,
  `AWS.Organizations.Operation`, `AWS.IdentityCenter.Operation`,
  `AWS.IAM.Operation`, `AWS.S3.Operation`,
  `AWS.Credentials.STS.Operation`).

  ## Required struct fields

    * `:method` — `:get | :post | :put | :delete | :head`
    * `:url` — fully-built URL string. The facade owns URL
      composition (path, query params, virtual-hosted addressing).
    * `:headers` — list of `{name, value}` tuples to include in the
      SigV4 canonical request (content-type, x-amz-target,
      x-amz-copy-source, range, ...).
    * `:body` — binary / iodata for buffered requests, or an
      `Enumerable.t()` when `:stream_upload` is `true`.
    * `:service` — SigV4 service name (e.g. `"s3"`, `"events"`).
    * `:region` — region string for the signing scope.
    * `:access_key_id`, `:secret_access_key` — signing credentials.

  ## Optional struct fields

    * `:security_token` — session token appended as
      `x-amz-security-token`.
    * `:payload_hash` — signer override for
      `x-amz-content-sha256`. Pass `"UNSIGNED-PAYLOAD"` for S3
      streaming uploads and presigned URLs.
    * `:stream_upload` (default `false`) — body is an `Enumerable`;
      dispatch via `HTTP.stream_upload/5`.
    * `:stream_response` (default `false`) — return `body_stream`
      instead of a buffered body; dispatch via
      `HTTP.stream_download/3`.
    * `:http` — opts forwarded to `AWS.HTTP` (`:connect_timeout`,
      `:request_timeout`).
    * `:now` — override `DateTime.utc_now/0` for deterministic
      signatures in tests.
  """
  @spec execute(struct) ::
          {:ok, response}
          | {:ok, stream_response}
          | {:error, {:http_error, non_neg_integer, binary}}
          | {:error, term}
  def execute(%_{} = op) do
    method = op.method
    url = op.url
    headers = op.headers
    body = Map.get(op, :body, "")
    stream_upload? = Map.get(op, :stream_upload, false)
    stream_response? = Map.get(op, :stream_response, false)
    http_opts = Map.get(op, :http, []) || []

    creds = build_creds(op)
    signing_body = if stream_upload?, do: "", else: body
    signed_headers = Signer.sign(method, url, headers, signing_body, creds)

    dispatch(method, url, body, signed_headers, stream_upload?, stream_response?, http_opts)
  end

  @doc """
  Resolves the endpoint / credentials / region map for a service.

  `namespace` picks the per-service opts key (e.g. `:s3`, `:events`)
  for endpoint-only overrides (`:scheme`, `:host`, `:port`, plus any
  `extra` keys). Credential keys (`:access_key_id`,
  `:secret_access_key`, `:security_token`, `:region`) are read from
  the flat top-level opts and resolved through `AWS.Config.new/2`.

  `default_host_fn` is a 1-arity function that receives the resolved
  region and returns the default host for the service.

  `extra` is an optional keyword list of additional keys to merge into
  the result from the namespace opts (e.g. S3 passes `[:path_style]`
  so callers can read `config.path_style` directly).
  """
  @spec resolve_config(atom, keyword, (String.t() -> String.t())) ::
          {:ok, map} | {:error, term}
  @spec resolve_config(atom, keyword, (String.t() -> String.t()), [atom]) ::
          {:ok, map} | {:error, term}
  def resolve_config(namespace, opts, default_host_fn, extra \\ []) do
    {svc_opts, cred_opts} = Keyword.pop(opts, namespace, [])
    {sandbox_opts, cred_opts} = Keyword.pop(cred_opts, :sandbox, [])

    cred_opts =
      if sandbox_local?(sandbox_opts) do
        merge_new(cred_opts, sandbox_cred_overrides())
      else
        cred_opts
      end

    resolved = Config.new(namespace, cred_opts)

    with {:ok, ak, sk, st} <- extract_creds(resolved) do
      region = resolved[:region] || "us-east-1"
      {scheme, host, port} = resolve_endpoint(svc_opts, sandbox_opts, default_host_fn, region)

      base = %{
        region: region,
        scheme: scheme,
        host: host,
        port: port,
        access_key_id: ak,
        secret_access_key: sk,
        security_token: st
      }

      {:ok, Enum.reduce(extra, base, fn key, acc -> Map.put(acc, key, svc_opts[key]) end)}
    end
  end

  defp extract_creds(%{access_key_id: ak, secret_access_key: sk} = resolved)
       when is_binary(ak) and is_binary(sk) do
    {:ok, ak, sk, Map.get(resolved, :security_token)}
  end

  defp extract_creds(_resolved), do: {:error, :missing_credentials}

  defp sandbox_cred_overrides do
    [access_key_id: "test", secret_access_key: "test", security_token: "test"]
  end

  defp merge_new(opts, extras) do
    Enum.reduce(extras, opts, fn {k, v}, acc -> Keyword.put_new(acc, k, v) end)
  end

  @doc """
  Builds a `"{scheme}://{host}{maybe_port}/"` URL for services that
  always POST to root (everyone except S3).
  """
  @spec simple_url(map) :: String.t()
  def simple_url(%{scheme: scheme, host: host, port: port}) do
    "#{scheme}://#{host}#{port_suffix(scheme, port)}/"
  end

  @doc """
  Returns `true` when the sandbox opts indicate `local` mode.
  Consumed by per-service clients that need to know whether to apply
  sandbox endpoint/credential overrides outside of `resolve_config/4`.
  """
  @spec sandbox_local?(keyword) :: boolean
  def sandbox_local?(sandbox_opts) do
    enabled = sandbox_opts[:enabled] || Config.sandbox_enabled?()
    mode = sandbox_opts[:mode] || Config.sandbox_mode()
    enabled and mode === :local
  end

  # -- dispatch ---------------------------------------------------------------

  defp dispatch(method, url, body, headers, true, _stream_resp?, http_opts) do
    method
    |> HTTP.stream_upload(url, body, headers, http_opts)
    |> translate_buffered()
  end

  defp dispatch(_method, url, _body, headers, false, true, http_opts) do
    case HTTP.stream_download(url, headers, http_opts) do
      {:ok, %{status_code: status} = resp} when status in 200..299 ->
        {:ok, resp}

      {:ok, %{status_code: status} = resp} ->
        body = resp |> Map.get(:body_stream, []) |> Enum.to_list() |> IO.iodata_to_binary()
        {:error, {:http_error, status, body}}

      {:error, %{reason: reason}} ->
        {:error, reason}
    end
  end

  defp dispatch(method, url, body, headers, false, false, http_opts) do
    method
    |> HTTP.request(url, body, headers, http_opts)
    |> translate_buffered()
  end

  defp translate_buffered({:ok, %{status_code: status} = resp}) when status in 200..299 do
    {:ok, resp}
  end

  defp translate_buffered({:ok, %{status_code: status, body: body}}) do
    {:error, {:http_error, status, body}}
  end

  defp translate_buffered({:error, %{reason: reason}}) do
    {:error, reason}
  end

  # -- signing creds map ------------------------------------------------------

  defp build_creds(op) do
    base = %{
      access_key_id: op.access_key_id,
      secret_access_key: op.secret_access_key,
      region: op.region,
      service: op.service,
      token: Map.get(op, :security_token),
      now: Map.get(op, :now) || DateTime.utc_now()
    }

    case Map.get(op, :payload_hash) do
      nil -> base
      hash -> Map.put(base, :payload_hash, hash)
    end
  end

  # -- endpoint + credential resolution --------------------------------------

  defp resolve_endpoint(svc_opts, sandbox_opts, default_host_fn, region) do
    if sandbox_local?(sandbox_opts) do
      {
        strip_scheme(svc_opts[:scheme] || Config.sandbox_scheme()),
        svc_opts[:host] || Config.sandbox_host(),
        svc_opts[:port] || Config.sandbox_port()
      }
    else
      {
        strip_scheme(svc_opts[:scheme] || "https"),
        svc_opts[:host] || default_host_fn.(region),
        svc_opts[:port]
      }
    end
  end

  # AWS.Config returns "http://" for sandbox scheme; strip trailing "://" so
  # we can URI-compose cleanly.
  defp strip_scheme(scheme) do
    scheme
    |> to_string()
    |> String.replace_suffix("://", "")
  end

  defp port_suffix(_scheme, nil), do: ""
  defp port_suffix("https", 443), do: ""
  defp port_suffix("http", 80), do: ""
  defp port_suffix(_scheme, port), do: ":#{port}"
end
