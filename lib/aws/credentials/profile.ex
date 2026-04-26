defmodule AWS.Credentials.Profile do
  @moduledoc """
  Loads a named profile by merging entries from `~/.aws/config` and
  `~/.aws/credentials`, and dispatches the loaded profile to the
  correct credential-resolution strategy.

  In `~/.aws/config`, profiles (other than `default`) are stored under
  `[profile foo]`. In `~/.aws/credentials`, the same profile lives
  under `[foo]`. Keys present in both files are resolved with
  `~/.aws/credentials` winning, matching the AWS CLI's behavior.

  The `sso-session` blocks in `~/.aws/config` are exposed via
  `load_sso_session/2`.

  `security_credentials/2` is the entry point consumed by
  `AWS.AuthCache` for the `{:awscli, profile, ttl}` source. It
  inspects the loaded profile and dispatches to the matching provider
  (SSO, credential_process, AssumeRole, or static keys).
  """

  alias AWS.Credentials.INI

  alias AWS.Credentials.Providers.{
    AssumeRole,
    CredentialProcess,
    SSO,
    StaticProfile
  }

  @type profile :: %{optional(String.t()) => String.t()}

  @doc """
  Returns the effective `~/.aws/config` path, honoring the
  `AWS_CONFIG_FILE` env var and the `:home_dir` opt.
  """
  @spec config_path(keyword) :: Path.t()
  def config_path(opts \\ []) do
    System.get_env("AWS_CONFIG_FILE") || default_config_path(opts)
  end

  defp default_config_path(opts), do: opts |> home() |> Path.join(".aws/config")

  @doc """
  Returns the effective `~/.aws/credentials` path, honoring the
  `AWS_SHARED_CREDENTIALS_FILE` env var and the `:home_dir` opt.
  """
  @spec credentials_path(keyword) :: Path.t()
  def credentials_path(opts \\ []) do
    System.get_env("AWS_SHARED_CREDENTIALS_FILE") || default_credentials_path(opts)
  end

  defp default_credentials_path(opts), do: opts |> home() |> Path.join(".aws/credentials")

  @doc """
  Loads a named profile, returning the merged key/value map or `nil`
  when the profile is defined in neither file.
  """
  @spec load(String.t(), keyword) :: profile | nil
  def load(profile_name, opts \\ []) when is_binary(profile_name) do
    config = load_file(config_path(opts))
    creds = load_file(credentials_path(opts))

    config_entry = Map.get(config, config_section_name(profile_name), %{})
    creds_entry = Map.get(creds, profile_name, %{})

    case Map.merge(config_entry, creds_entry) do
      empty when map_size(empty) === 0 -> nil
      merged -> merged
    end
  end

  @doc """
  Loads an `[sso-session NAME]` block from `~/.aws/config`.

  Returns the session's key/value map or `nil` when no such block
  exists.
  """
  @spec load_sso_session(String.t(), keyword) :: profile | nil
  def load_sso_session(session_name, opts \\ []) when is_binary(session_name) do
    config = load_file(config_path(opts))
    Map.get(config, "sso-session " <> session_name)
  end

  @doc """
  The default profile name, honoring `AWS_PROFILE` then `AWS_DEFAULT_PROFILE`.
  """
  @spec default :: String.t()
  def default do
    System.get_env("AWS_PROFILE") || System.get_env("AWS_DEFAULT_PROFILE") || "default"
  end

  @doc """
  Resolves credentials for a named profile by dispatching based on
  profile content.

  Dispatch order:

    1. `sso_session` or `sso_start_url` → `AWS.Credentials.Providers.SSO`
    2. `credential_process` → `AWS.Credentials.Providers.CredentialProcess`
    3. `role_arn` → `AWS.Credentials.Providers.AssumeRole`
    4. `aws_access_key_id` → `AWS.Credentials.Providers.StaticProfile`

  Returns `{:ok, creds}` where `creds` is a map with at least
  `:access_key_id` and `:secret_access_key`, plus `:security_token`,
  `:expires_at`, `:region`, and `:source` when available.

  Returns `{:error, reason}` when the profile cannot be resolved or
  does not carry any of the dispatch keys above.
  """
  @spec security_credentials(String.t(), keyword) :: {:ok, map} | {:error, term}
  def security_credentials(profile_name, opts \\ []) when is_binary(profile_name) do
    case load(profile_name, opts) do
      nil ->
        {:error, {:profile_not_found, profile_name}}

      profile ->
        provider_opts = Keyword.put(opts, :profile, profile_name)

        profile
        |> dispatch(provider_opts)
        |> interpret_dispatch(profile_name)
        |> maybe_put_region(profile)
    end
  end

  defp dispatch(profile, opts) do
    cond do
      is_binary(profile["sso_session"]) or is_binary(profile["sso_start_url"]) ->
        SSO.resolve(opts)

      is_binary(profile["credential_process"]) ->
        CredentialProcess.resolve(opts)

      is_binary(profile["role_arn"]) ->
        AssumeRole.resolve(opts)

      is_binary(profile["aws_access_key_id"]) ->
        StaticProfile.resolve(opts)

      true ->
        {:error, :unresolvable_profile}
    end
  end

  defp interpret_dispatch({:ok, creds}, _profile_name), do: {:ok, creds}
  defp interpret_dispatch({:error, _} = err, _profile_name), do: err

  defp interpret_dispatch(:skip, profile_name),
    do: {:error, {:unresolvable_profile, profile_name}}

  defp maybe_put_region({:ok, creds}, profile) do
    case profile["region"] do
      region when is_binary(region) and region !== "" ->
        {:ok, Map.put_new(creds, :region, region)}

      _ ->
        {:ok, creds}
    end
  end

  defp maybe_put_region(result, _profile), do: result

  defp config_section_name("default"), do: "default"
  defp config_section_name(profile), do: "profile " <> profile

  defp load_file(path) do
    case INI.read(path) do
      {:ok, sections} -> sections
      {:error, _} -> %{}
    end
  end

  defp home(opts) do
    opts[:home_dir] || System.user_home!()
  end
end
