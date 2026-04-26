defmodule AWS.Credentials.Providers.CredentialProcess do
  @moduledoc """
  Runs the profile's `credential_process` command and parses its JSON
  output.

  The AWS CLI documents the expected output shape at
  https://docs.aws.amazon.com/cli/latest/topic/config-vars.html#sourcing-credentials-from-external-processes:

      {
        "Version": 1,
        "AccessKeyId": "...",
        "SecretAccessKey": "...",
        "SessionToken": "...",
        "Expiration": "2026-04-16T19:00:00Z"
      }
  """

  alias AWS.Credentials.Profile

  @doc false
  def resolve(opts) do
    profile_name = opts[:profile] || Profile.default()

    with profile when is_map(profile) <- Profile.load(profile_name, opts),
         command when is_binary(command) <- profile["credential_process"] do
      run(command)
    else
      _ -> :skip
    end
  end

  defp run(command) do
    [bin | args] = OptionParser.split(command)

    case System.cmd(bin, args, stderr_to_stdout: true) do
      {output, 0} -> parse(output)
      {output, status} -> {:error, {:credential_process_failed, status, String.trim(output)}}
    end
  rescue
    err -> {:error, {:credential_process_failed, :exception, Exception.message(err)}}
  end

  defp parse(output) do
    case decode_json(output) do
      {:ok, %{"Version" => 1} = body} ->
        build(body)

      {:ok, body} ->
        {:error, {:credential_process_invalid, {:unsupported_version, body["Version"]}}}

      {:error, reason} ->
        {:error, {:credential_process_invalid, reason}}
    end
  end

  defp decode_json(binary) do
    {:ok, :json.decode(binary)}
  rescue
    err -> {:error, Exception.message(err)}
  end

  defp build(body) do
    with {:ok, ak} <- fetch_string(body, "AccessKeyId"),
         {:ok, sk} <- fetch_string(body, "SecretAccessKey") do
      {:ok,
       %{
         access_key_id: ak,
         secret_access_key: sk,
         security_token: optional_string(body, "SessionToken"),
         expires_at: parse_expiration(body["Expiration"]),
         source: :credential_process
       }}
    end
  end

  defp fetch_string(body, key) do
    case Map.get(body, key) do
      v when is_binary(v) and v !== "" -> {:ok, v}
      _ -> {:error, {:missing_field, key}}
    end
  end

  defp optional_string(body, key) do
    case Map.get(body, key) do
      v when is_binary(v) and v !== "" -> v
      _ -> nil
    end
  end

  defp parse_expiration(nil), do: nil

  defp parse_expiration(binary) when is_binary(binary) do
    case DateTime.from_iso8601(binary) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
