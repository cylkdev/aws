defmodule AWS.Credentials.Providers.AssumeRole do
  @moduledoc """
  Resolves credentials from a profile that carries a `role_arn`.

  The profile must identify a `source_profile` (or `credential_source`,
  not yet supported) to produce the caller identity used to sign the
  `AssumeRole` request. The source profile is resolved by re-dispatching
  through `AWS.Credentials.Profile.security_credentials/2`.

  Session name defaults to `aws-elixir-<unix-ts>` and can be overridden
  via `role_session_name` on the profile.

  STS is invoked during credential resolution, so the
  `AWS.Client.execute/1` dispatcher is used with pre-resolved source
  credentials baked onto the Operation struct.

  STS's public API is XML-only at the AWS wire level. The service model
  (`botocore/data/sts/2011-06-15/service-2.json`) declares
  `metadata.protocols = ["query"]`, and AWS does not expose a JSON STS
  endpoint, which is why this provider parses XML via `SweetXml` despite
  the rest of the library speaking JSON.
  """

  import SweetXml, only: [sigil_x: 2, xpath: 3]

  alias AWS.Client
  alias AWS.Credentials.Profile
  alias AWS.Credentials.STS.Operation

  @default_duration_seconds 3_600
  @service "sts"

  @doc false
  def resolve(opts) do
    profile_name = opts[:profile] || Profile.default()

    case Profile.load(profile_name, opts) do
      nil ->
        :skip

      profile ->
        resolve_with_profile(profile, opts)
    end
  end

  defp resolve_with_profile(profile, opts) do
    role_arn = profile["role_arn"]
    source = profile["source_profile"]

    cond do
      is_nil(role_arn) -> :skip
      is_nil(source) -> {:error, :assume_role_missing_source_profile}
      true -> assume(role_arn, source, profile, opts)
    end
  end

  defp assume(role_arn, source_profile, profile, opts) do
    region = profile["region"] || "us-east-1"

    base_params = %{
      role_arn: role_arn,
      role_session_name: session_name(profile),
      duration_seconds: duration(profile)
    }

    params = maybe_put(base_params, :external_id, profile["external_id"])

    with {:ok, source} <- Profile.security_credentials(source_profile, opts),
         {:ok, result} <- assume_role(params, source, region, opts) do
      {:ok,
       %{
         access_key_id: result.access_key_id,
         secret_access_key: result.secret_access_key,
         security_token: result.session_token,
         expires_at: result.expiration,
         source: :sts
       }}
    end
  end

  defp assume_role(params, source, region, opts) do
    op = %Operation{
      method: :post,
      url: endpoint(region, opts),
      headers: [{"content-type", "application/x-www-form-urlencoded"}],
      body: form_body("AssumeRole", params),
      service: @service,
      region: region,
      access_key_id: source.access_key_id,
      secret_access_key: source.secret_access_key,
      security_token: Map.get(source, :security_token),
      http: Keyword.get(opts, :http, [])
    }

    case Client.execute(op) do
      {:ok, %{body: xml}} -> parse_assume_role(xml)
      {:error, {:http_error, status, xml}} -> {:error, {:sts_http_error, status, xml}}
      {:error, reason} -> {:error, {:sts_transport_error, reason}}
    end
  end

  defp parse_assume_role(xml) do
    parsed =
      xpath(
        xml,
        ~x"//AssumeRoleResponse/AssumeRoleResult/Credentials",
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

  defp parse_expiration(""), do: nil

  defp parse_expiration(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp form_body(action, params) do
    base = [
      {"Action", action},
      {"Version", "2011-06-15"},
      {"RoleArn", params.role_arn},
      {"RoleSessionName", params.role_session_name},
      {"DurationSeconds",
       Integer.to_string(params[:duration_seconds] || @default_duration_seconds)}
    ]

    base
    |> maybe_add("ExternalId", params[:external_id])
    |> maybe_add("SerialNumber", params[:serial_number])
    |> maybe_add("TokenCode", params[:token_code])
    |> URI.encode_query()
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: list ++ [{key, value}]

  defp endpoint(region, opts) do
    opts[:endpoint] || "https://sts.#{region}.amazonaws.com/"
  end

  defp session_name(profile) do
    profile["role_session_name"] || "aws-elixir-#{System.system_time(:second)}"
  end

  defp duration(profile) do
    case profile["duration_seconds"] do
      nil -> 3_600
      seconds when is_binary(seconds) -> String.to_integer(seconds)
      seconds when is_integer(seconds) -> seconds
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
