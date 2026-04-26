defmodule AWS.ConfigNew do
  alias AWS.AuthCache

  @app :aws

  @access_key_id [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_REGION"},
    :pod_identity,
    :instance_role,
    "<AWS_ACCESS_KEY_ID>"
  ]

  @secret_access_key [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_REGION"},
    :pod_identity,
    :instance_role,
    "<AWS_SECRET_ACCESS_KEY>"
  ]

  @security_token [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_REGION"},
    :pod_identity,
    :instance_role,
    "<AWS_SECURITY_TOKEN>"
  ]

  @region [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_REGION"},
    :pod_identity,
    :instance_role,
    "us-east-1"
  ]

  @sandbox_options [
    mode: :local,
    scheme: "http://",
    host: "localhost",
    port: 4566
  ]

  @sandbox_enabled false
  @sandbox_mode :local

  defstruct [
    :access_key_id,
    :secret_access_key,
    :security_token,
    :region,
    :sandbox_enabled,
    :sandbox_mode,
    :sandbox_options
  ]

  def new(overrides, opts) do
    __config__()
    |> Keyword.merge(overrides)
    |> Enum.reduce([], fn {k, providers}, acc ->
      Keyword.put(acc, k, resolve_providers(providers, opts))
    end)
    |> then(&struct(__MODULE__, &1))
  end

  def __config__ do
    [
      access_key_id: access_key_id(),
      secret_access_key: secret_access_key(),
      security_token: security_token(),
      region: region(),
      sandbox_enabled: sandbox_enabled(),
      sandbox_mode: sandbox_mode(),
      sandbox_options: sandbox_options()
    ]
  end

  defp resolve_providers(providers, opts) do
    Enum.reduce_while(providers, nil, fn provider, acc ->
      case resolve_provider_value(provider, opts) do
        nil -> {:cont, acc}
        value -> {:halt, value}
      end
    end)
  end

  defp resolve_provider_value({:system, env_var}, _opts) do
    System.get_env(env_var)
  end

  defp resolve_provider_value(:instance_role, opts) do
    case AuthCache.get(:aws_instance_auth, opts) do
      {:ok, creds} -> creds
      {:error, _reason} -> nil
    end
  end

  defp resolve_provider_value(:ecs_task_role, opts) do
    case AuthCache.get(:aws_ecs_auth, opts) do
      {:ok, creds} -> creds
      {:error, _reason} -> nil
    end
  end

  defp resolve_provider_value({:awscli, {:system, env_var}}, opts) do
    resolve_provider_value({:awscli, System.get_env(env_var), 30}, opts)
  end

  defp resolve_provider_value({:awscli, profile}, opts) do
    resolve_provider_value({:awscli, profile, 30}, opts)
  end

  defp resolve_provider_value({:awscli, profile, ttl_seconds}, opts) do
    awscli_opts = Keyword.put(opts, :ttl_seconds, ttl_seconds)

    case AuthCache.get({:awscli, profile}, awscli_opts) do
      {:ok, creds} -> creds
      {:error, _reason} -> nil
    end
  end

  defp resolve_provider_value(value, _opts), do: value

  def access_key_id do
    Application.get_env(@app, :access_key_id) || @access_key_id
  end

  def secret_access_key do
    Application.get_env(@app, :secret_access_key) || @secret_access_key
  end

  def security_token do
    Application.get_env(@app, :security_token) || @security_token
  end

  def region do
    Application.get_env(@app, :region) || @region
  end

  def sandbox_enabled do
    Application.get_env(@app, :sandbox_enabled) || @sandbox_enabled
  end

  def sandbox_mode do
    Application.get_env(@app, :sandbox_mode) || @sandbox_options[:mode]
  end

  def sandbox_options do
    Application.get_env(@app, :sandbox_options) || @sandbox_options
  end
end
