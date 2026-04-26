defmodule AWS.HTTP do
  @moduledoc """
  `Req`-based HTTP primitive for direct AWS API calls.

  All requests run through a single supervised `Finch` instance
  (`AWS.HTTP.FinchPool`), which holds a dedicated pool per well-known AWS
  service endpoint plus a `:default` pool for S3 virtual-hosted bucket
  origins. Control-plane services use HTTP/2 multiplexing; S3 stays on
  HTTP/1.1. See `AWS.HTTP.FinchPool` for tuning.

  Req's defaults (retries, redirect following, body decoding,
  request/response compression) are all **disabled** here because:

    * AWS clients sign a specific set of headers and bytes; Req
      retrying, following a redirect, or rewriting the body would
      invalidate the SigV4 signature produced upstream.
    * AWS services return raw JSON/XML/binary that the caller parses
      itself, so Req's content-type decoding would surprise callers.

  Three entry points:

    * `request/5` (plus `post/4` and `get/3`) — buffered bodies both
      directions. Appropriate for everything that fits in memory:
      JSON/Query API calls, list operations, header-only operations.

    * `stream_upload/5` — body is an `Enumerable` of iodata chunks
      (S3 large PUTs, multipart `upload_part`). Response is buffered.

    * `stream_download/3` — body is read lazily via a returned
      `Stream`. Used for large S3 downloads. The stream must be
      consumed in the calling process because Finch routes response
      messages to that process.
  """

  alias AWS.HTTP.FinchPool

  @default_request_timeout 30_000

  @type method :: :get | :post | :put | :delete | :head | :patch | :options
  @type header :: {String.t(), String.t()}
  @type response :: %{status_code: non_neg_integer(), headers: [header], body: binary}
  @type stream_response :: %{
          status_code: non_neg_integer(),
          headers: [header],
          body_stream: Enumerable.t()
        }

  def start_link(opts \\ []) do
    FinchPool.start_link(opts)
  end

  def child_spec(opts \\ []) do
    FinchPool.child_spec(opts)
  end

  @doc """
  Issues a buffered HTTP request.

  ## Options

    * `:request_timeout` — milliseconds for the whole response, default `#{@default_request_timeout}`.
      Forwarded to Finch as `:receive_timeout`.
    * `:connect_timeout` — accepted for API compatibility and ignored here;
      connect timeouts live on the Finch pool configured in `AWS.HTTP.FinchPool`.
  """
  @spec request(method, String.t(), iodata, [header], keyword) ::
          {:ok, response} | {:error, %{reason: term}}
  def request(method, url, body, headers, opts \\ []) when is_atom(method) do
    validate_url!(url)

    [method: method, url: url, headers: headers, body: body]
    |> Keyword.merge(base_opts(opts))
    |> Req.request()
    |> handle_response()
  end

  @doc "Convenience wrapper for `request(:post, url, body, headers, opts)`."
  @spec post(String.t(), iodata, [header], keyword) :: {:ok, response} | {:error, %{reason: term}}
  def post(url, body, headers, opts \\ []) do
    request(:post, url, body, headers, opts)
  end

  @doc "Convenience wrapper for `request(:get, url, \"\", headers, opts)`."
  @spec get(String.t(), [header], keyword) :: {:ok, response} | {:error, %{reason: term}}
  def get(url, headers \\ [], opts \\ []) do
    request(:get, url, "", headers, opts)
  end

  @doc """
  Sends a request whose body is produced by an `Enumerable` of iodata
  chunks. Response body is buffered.

  The caller should set `content-length` on the request headers — S3
  requires it for SigV4 unsigned-payload streaming. `content-type` and
  other S3 headers should be included in `headers` so they are part of
  the signature computed upstream.
  """
  @spec stream_upload(method, String.t(), Enumerable.t(), [header], keyword) ::
          {:ok, response} | {:error, %{reason: term}}
  def stream_upload(method, url, body_stream, headers, opts \\ []) when is_atom(method) do
    _ = validate_url!(url)

    [method: method, url: url, headers: headers, body: body_stream]
    |> Keyword.merge(base_opts(opts))
    |> Req.request()
    |> handle_response()
  end

  @doc """
  Issues a GET request and returns a `Stream` over the response body
  chunks. The stream must be consumed in the calling process because
  Finch routes response messages to that process.
  """
  @spec stream_download(String.t(), [header], keyword) ::
          {:ok, stream_response} | {:error, %{reason: term}}
  def stream_download(url, headers \\ [], opts \\ []) do
    _ = validate_url!(url)
    timeout = request_timeout(opts)

    result =
      [method: :get, url: url, headers: headers, into: :self]
      |> Keyword.merge(base_opts(opts))
      |> Req.request()

    case result do
      {:ok, %Req.Response{status: status, headers: resp_headers} = response} ->
        {:ok,
         %{
           status_code: status,
           headers: to_list_headers(resp_headers),
           body_stream: body_stream(response, timeout)
         }}

      {:error, error} ->
        {:error, %{reason: error_reason(error)}}
    end
  end

  defp base_opts(opts) do
    [
      finch: FinchPool.name(),
      receive_timeout: request_timeout(opts),
      retry: false,
      redirect: false,
      decode_body: false,
      compressed: false
    ]
  end

  defp handle_response({:ok, %Req.Response{status: status, headers: headers, body: body}}) do
    {:ok,
     %{
       status_code: status,
       headers: to_list_headers(headers),
       body: to_binary(body)
     }}
  end

  defp handle_response({:error, error}), do: {:error, %{reason: error_reason(error)}}

  defp body_stream(%Req.Response{body: %Req.Response.Async{}} = response, timeout) do
    Stream.resource(
      fn -> {response, []} end,
      fn state -> step(state, timeout) end,
      fn {response, _pending} ->
        _ = Req.cancel_async_response(response)
        :ok
      end
    )
  end

  defp step({response, []}, timeout) do
    receive do
      msg ->
        case Req.parse_message(response, msg) do
          {:ok, events} -> step({response, events}, timeout)
          {:error, _exception} -> {:halt, {response, []}}
          :unknown -> {[], {response, []}}
        end
    after
      timeout -> {:halt, {response, []}}
    end
  end

  defp step({response, [:done | _]}, _timeout), do: {:halt, {response, []}}
  defp step({response, [{:data, chunk} | rest]}, _timeout), do: {[chunk], {response, rest}}
  defp step({response, [_other | rest]}, timeout), do: step({response, rest}, timeout)

  defp to_list_headers(headers) when is_map(headers) do
    for {k, vs} <- headers, v <- List.wrap(vs), do: {to_string(k), to_string(v)}
  end

  defp to_binary(body) when is_binary(body), do: body
  defp to_binary(nil), do: ""
  defp to_binary(body) when is_list(body), do: IO.iodata_to_binary(body)

  defp request_timeout(opts) do
    Keyword.get(opts, :request_timeout, @default_request_timeout)
  end

  defp error_reason(%{reason: reason}), do: reason
  defp error_reason(other), do: other

  defp validate_url!(url) do
    uri = URI.parse(url)
    :ok = validate_host!(uri)
    :ok = validate_scheme!(uri)
  end

  defp validate_host!(uri) do
    case uri do
      %URI{host: host} when is_binary(host) and host !== "" -> :ok
      %URI{} -> raise ArgumentError, "missing host in url: #{inspect(uri)}"
    end
  end

  defp validate_scheme!(uri) do
    case uri do
      %URI{scheme: "https"} -> :ok
      %URI{scheme: "http"} -> :ok
      %URI{scheme: scheme} -> raise ArgumentError, "unsupported scheme: #{inspect(scheme)}"
    end
  end
end
