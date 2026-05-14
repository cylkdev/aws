defmodule AWS.Config do
  @moduledoc """
  Runtime configuration for the `:aws` library.

  Each credential / region key has a default source chain held in a
  module attribute. Callers can override the chain per-field via the
  application environment or per-call via `opts`. `lookup/3` walks the
  chain, resolving entries against `resolve/3` and returning the first
  non-nil value.

  ## Source chain entries

    | Entry                                       | Resolves to                                                   |
    |---------------------------------------------|---------------------------------------------------------------|
    | binary literal                              | itself (trimmed; empty string treated as nil)                 |
    | `{:system, "ENV_VAR"}`                      | `System.get_env("ENV_VAR")` (trimmed; empty treated as nil)   |
    | `:instance_role`                            | `key` field of EC2 IMDSv2 creds map                           |
    | `:ecs_task_role`                            | `key` field of ECS container creds map                        |
    | `{:awscli, profile, ttl_seconds}`           | `key` field of shared-profile creds map                       |
    | `{:awscli, {:system, "ENV_VAR"}, ttl_seconds}` | profile name read from env, then dispatched as `{:awscli, profile, ttl}` |

  ## Precedence

  **Per-call opts > app env > built-in defaults.** A caller passing
  `access_key_id: "X"` ignores any app-env `:access_key_id` chain.

  ## Sandbox configuration

  `sandbox/1` returns a merged keyword list combining the built-in
  defaults, the `:aws` `:sandbox` app-env entry, and the `:sandbox`
  key in caller opts.
  """

  alias AWS.AuthCache

  @app :aws

  @access_key_id [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_ACCESS_KEY_ID"},
    :instance_role,
    :ecs_task_role
  ]

  @secret_access_key [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_SECRET_ACCESS_KEY"},
    :instance_role,
    :ecs_task_role
  ]

  @security_token [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_SESSION_TOKEN"},
    :instance_role,
    :ecs_task_role
  ]

  @region [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_REGION"},
    {:system, "AWS_DEFAULT_REGION"},
    "us-east-1"
  ]

  @sandbox [enabled: false]

  @doc """
  Aggregates every per-key resolver into a single keyword list. Caller
  opts thread through to each resolver, including the `:sandbox`
  override map.
  """
  @spec new(keyword) :: keyword
  def new(opts \\ []) when is_list(opts) do
    [
      access_key_id: access_key_id(opts),
      secret_access_key: secret_access_key(opts),
      security_token: security_token(opts),
      region: region(opts),
      sandbox: sandbox(opts)
    ]
  end

  @doc "Resolves the access key id chain."
  @spec access_key_id(keyword) :: String.t() | nil
  def access_key_id(opts \\ []) do
    opts
    |> source(:access_key_id, @access_key_id)
    |> lookup(:access_key_id, opts)
  end

  @doc "Resolves the secret access key chain."
  @spec secret_access_key(keyword) :: String.t() | nil
  def secret_access_key(opts \\ []) do
    opts
    |> source(:secret_access_key, @secret_access_key)
    |> lookup(:secret_access_key, opts)
  end

  @doc "Resolves the security (session) token chain."
  @spec security_token(keyword) :: String.t() | nil
  def security_token(opts \\ []) do
    opts
    |> source(:security_token, @security_token)
    |> lookup(:security_token, opts)
  end

  @doc """
  Resolves the region chain. Falls back to `\"us-east-1\"` because the
  built-in chain ends with that literal.
  """
  @spec region(keyword) :: String.t()
  def region(opts \\ []) do
    opts
    |> source(:region, @region)
    |> lookup(:region, opts)
  end

  @doc """
  Returns the merged sandbox keyword list. Defaults are overlaid with
  the `:aws` `:sandbox` app-env entry, then with `opts[:sandbox]`.
  """
  @spec sandbox(keyword) :: keyword
  def sandbox(opts \\ []) do
    @sandbox
    |> Keyword.merge(Application.get_env(@app, :sandbox, []))
    |> Keyword.merge(Keyword.get(opts, :sandbox, []))
  end

  # ---------------------------------------------------------------------------

  defp source(opts, key, default) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> value
      :error -> Application.get_env(@app, key, default)
    end
  end

  defp lookup(value, key, opts) do
    value
    |> List.wrap()
    |> Enum.find_value(&resolve(&1, key, opts))
  end

  defp resolve(value, _key, _opts) when is_binary(value), do: present(value)

  defp resolve({:system, env_var}, _key, _opts) do
    present(System.get_env(env_var))
  end

  defp resolve({:awscli, {:system, env_var}, ttl_seconds}, key, opts) do
    case present(System.get_env(env_var)) do
      nil -> nil
      profile -> resolve({:awscli, profile, ttl_seconds}, key, opts)
    end
  end

  defp resolve({:awscli, profile, ttl_seconds}, key, opts) do
    awscli_opts = Keyword.put(opts, :ttl_seconds, ttl_seconds)

    {:awscli, profile}
    |> AuthCache.get(awscli_opts)
    |> field(key)
  end

  defp resolve(:instance_role, key, opts) do
    :aws_instance_auth
    |> AuthCache.get(opts)
    |> field(key)
  end

  defp resolve(:ecs_task_role, key, opts) do
    :aws_ecs_auth
    |> AuthCache.get(opts)
    |> field(key)
  end

  defp resolve(_value, _key, _opts), do: nil

  defp field({:ok, creds}, key) when is_map(creds), do: present(Map.get(creds, key))
  defp field({:error, _reason}, _key), do: nil

  defp present(nil), do: nil
  defp present(""), do: nil
  defp present(value) when is_binary(value), do: trim_or_nil(String.trim(value))
  defp present(value), do: value

  defp trim_or_nil(""), do: nil
  defp trim_or_nil(value), do: value
end
