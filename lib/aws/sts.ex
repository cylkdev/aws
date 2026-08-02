defmodule AWS.STS do
  @moduledoc """
  `AWS.STS` provides an API for AWS Security Token Service (STS).

  This module calls the AWS STS Query API directly via `AWS.HTTP` and
  `AWS.Signer` (through `AWS.Client`).

  STS's public API is XML-only at the AWS wire level. The service model
  (`botocore/data/sts/2011-06-15/service-2.json`) declares
  `metadata.protocols = ["query"]`, and AWS does not expose a JSON STS
  endpoint. The form-urlencoded request / XML response handling here
  (XPath extraction via `SweetXml`) is a consequence of AWS's protocol
  choice, not a library decision.

  STS exposes both a legacy global endpoint (`sts.amazonaws.com`) and
  regional endpoints at `sts.{region}.amazonaws.com`. This facade uses
  the regional form (mirroring the AWS CLI's default behavior), signed
  under the configured `:region` (default `us-east-1`).

  ## Shared Options

  Credentials and region are flat top-level opts on every call (ex_aws shape).
  Each accepts a literal, a source tuple, or a list of sources (first
  non-nil wins):

    - `:access_key_id`, `:secret_access_key`, `:security_token`, `:region` -
      Sources: literal binary, `{:system, "ENV"}`, `:instance_role`,
      `:ecs_task_role`, `{:awscli, profile}` / `{:awscli, profile, ttl}`,
      a module, or a list of any of these. Map-returning sources merge
      into the outer config. `{:awscli, _}` is not in the default chain -
      callers opt in explicitly.

  The following options are also available:

    - `:sts` - A keyword list of STS endpoint overrides. Supported keys:
      `:scheme`, `:host`, `:port`. Credentials are not read from this
      sub-list; use the top-level keys above.

    - `:sandbox` - A keyword list to override sandbox configuration.
        - `:enabled` - Whether sandbox mode is enabled.

  ## Sandbox

  Set `sandbox: [enabled: true]` to activate sandbox mode.

  ### Setup

  Add the following to your `test_helper.exs`:

      AWS.STS.Sandbox.start_link()

  ### Usage

      setup do
        AWS.STS.Sandbox.set_get_caller_identity_responses([
          fn -> {:ok, %{account: "123456789012", arn: "arn:aws:iam::123456789012:user/alice", user_id: "AIDA123"}} end
        ])
      end

      test "returns caller identity" do
        assert {:ok, %{account: "123456789012"}} =
                 AWS.STS.get_caller_identity(sandbox: [enabled: true])
      end
  """

  import SweetXml, only: [xpath: 3, sigil_x: 2]

  use AWS.Service,
    sandbox: AWS.STS.Sandbox,
    operations: [
      get_caller_identity: 1
    ]

  alias AWS.Client
  alias AWS.Operation

  @service "sts"
  @content_type "application/x-www-form-urlencoded"
  @api_version "2011-06-15"
  @default_region "us-east-1"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Returns details about the IAM user or role whose credentials are used
  to call the operation.

  Wraps the STS `GetCallerIdentity` action. No request parameters are
  required - the response is derived from the signing credentials.

  Returns `{:ok, %{account: String.t(), arn: String.t(), user_id: String.t()}}`
  on success.
  """
  @spec get_caller_identity(opts :: keyword()) ::
          {:ok, %{account: String.t(), arn: String.t(), user_id: String.t()}}
          | {:error, term()}
  def get_caller_identity(opts \\ []) do
    if sandbox?(opts) do
      sandbox_get_caller_identity_response(opts)
    else
      do_get_caller_identity(opts)
    end
  end

  defp do_get_caller_identity(opts) do
    "GetCallerIdentity"
    |> perform(%{}, opts)
    |> deserialize_response(opts, fn body ->
      fields =
        xpath(body, ~x"//GetCallerIdentityResult"e,
          account: ~x"./Account/text()"s,
          arn: ~x"./Arn/text()"s,
          user_id: ~x"./UserId/text()"s
        )

      {:ok, fields}
    end)
  end

  # ---------------------------------------------------------------------------
  # Internal: AssumeRole helper for credential resolution
  # ---------------------------------------------------------------------------

  @doc false
  @spec assume_role(map, map, String.t(), keyword) ::
          {:ok,
           %{
             access_key_id: String.t(),
             secret_access_key: String.t(),
             session_token: String.t(),
             expiration: DateTime.t() | nil
           }}
          | {:error, term}
  def assume_role(params, source_creds, region, opts) do
    op = %Operation{
      method: :post,
      url: opts[:endpoint] || default_url(region),
      headers: [{"content-type", @content_type}],
      body: assume_role_body(params),
      service: @service,
      region: region,
      access_key_id: source_creds.access_key_id,
      secret_access_key: source_creds.secret_access_key,
      security_token: Map.get(source_creds, :security_token),
      http: Keyword.get(opts, :http, [])
    }

    case Client.execute(op) do
      {:ok, %{body: xml}} -> parse_assume_role(xml)
      {:error, {:http_error, status, xml}} -> {:error, {:sts_http_error, status, xml}}
      {:error, reason} -> {:error, {:sts_transport_error, reason}}
    end
  end

  defp assume_role_body(params) do
    base = [
      {"Action", "AssumeRole"},
      {"Version", @api_version},
      {"RoleArn", params.role_arn},
      {"RoleSessionName", params.role_session_name},
      {"DurationSeconds", Integer.to_string(params[:duration_seconds] || 3_600)}
    ]

    base
    |> maybe_add("ExternalId", params[:external_id])
    |> maybe_add("SerialNumber", params[:serial_number])
    |> maybe_add("TokenCode", params[:token_code])
    |> URI.encode_query()
  end

  defp parse_assume_role(xml) do
    parsed =
      xpath(
        xml,
        ~x"//AssumeRoleResponse/AssumeRoleResult/Credentials"e,
        access_key_id: ~x"./AccessKeyId/text()"s,
        secret_access_key: ~x"./SecretAccessKey/text()"s,
        session_token: ~x"./SessionToken/text()"s,
        expiration: ~x"./Expiration/text()"s
      )

    case parsed do
      %{access_key_id: ak, secret_access_key: sk, session_token: st, expiration: exp}
      when ak !== "" and sk !== "" ->
        {:ok,
         %{
           access_key_id: ak,
           secret_access_key: sk,
           session_token: st,
           expiration: parse_expiration(exp)
         }}

      _ ->
        {:error, {:sts_invalid_response, xml}}
    end
  rescue
    err -> {:error, {:sts_invalid_response, Exception.message(err)}}
  end

  # An absent Expiration is legitimate; an unparseable one is not. Returning
  # nil for the latter would mean "never expires", and `AWS.AuthCache` caches
  # an entry with no expiry forever -- the credentials would die at AWS while
  # this process kept reusing them. Raise instead; the caller's rescue turns
  # it into `{:error, {:sts_invalid_response, _}}`.
  defp parse_expiration(""), do: nil

  defp parse_expiration(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> dt
      {:error, reason} -> raise ArgumentError, "unparseable Expiration #{inspect(iso)}: #{reason}"
    end
  end

  defp default_url(region), do: "https://sts.#{region}.amazonaws.com/"

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: list ++ [{key, value}]

  # ---------------------------------------------------------------------------
  # Sandbox delegation
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Private helpers (Query-protocol perform/build/deserialize)
  # ---------------------------------------------------------------------------

  @doc false
  def build_operation(action, params, opts) do
    opts = Keyword.put_new(opts, :region, @default_region)

    with {:ok, config} <- Client.resolve_config(:sts, opts, &default_host/1) do
      op = %Operation{
        method: :post,
        url: Client.simple_url(config),
        headers: [{"content-type", @content_type}],
        body: encode_body(action, params),
        service: @service,
        region: config.region,
        access_key_id: config.access_key_id,
        secret_access_key: config.secret_access_key,
        security_token: config.security_token,
        http: Keyword.get(opts, :http, [])
      }

      {:ok, apply_overrides(op, opts[:sts] || [])}
    end
  end

  defp perform(action, params, opts) do
    with {:ok, op} <- build_operation(action, params, opts) do
      case Client.execute(op) do
        {:ok, %{body: body}} -> {:ok, body}
        {:error, _} = err -> err
      end
    end
  end

  defp encode_body(action, params) do
    params
    |> Map.merge(%{"Action" => action, "Version" => @api_version})
    |> URI.encode_query()
  end

  defp default_host(region), do: "sts.#{region}.amazonaws.com"
end
