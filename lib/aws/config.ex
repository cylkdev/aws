defmodule AWS.Config do
  @moduledoc """
  Runtime configuration for the `:aws` library.

  Owns:

    * **Credential & region resolution** via `new/2`, `build_base/2`,
      `retrieve_runtime_value/3`, and `retrieve_runtime_config/2`.
      Port of `ExAws.Config`: each of `:access_key_id`,
      `:secret_access_key`, `:security_token`, and `:region` accepts a
      literal, a source tuple / atom, or a list of sources (first
      non-nil wins). Map-returning sources (`:instance_role`,
      `:ecs_task_role`, `{:awscli, _, _}`) are merged into the outer
      config so one source can populate multiple keys.

    * **Sandbox configuration** (`sandbox/0`, `sandbox_enabled?/0`,
      `sandbox_mode/0`, `sandbox_scheme/0`, `sandbox_host/0`,
      `sandbox_port/0`, `sandbox_credentials/0`,
      `put_sandbox_credentials/1`) used by local-dev emulators
      (LocalStack / MinIO).

  ## Credential sources

    | Source                                  | Returns                                                |
    |-----------------------------------------|--------------------------------------------------------|
    | literal binary                          | itself                                                 |
    | `{:system, "ENV_VAR"}`                  | `System.get_env("ENV_VAR")`                            |
    | `:instance_role`                        | EC2 IMDSv2 creds map                                   |
    | `:ecs_task_role`                        | ECS container creds map                                |
    | `{:awscli, name}` / `{:awscli, name, ttl}` | shared-profile creds map (static / SSO / process / assume_role) |
    | list of any of the above                | first non-nil wins                                     |

  ## Defaults

  When a field is omitted from caller opts and app env, it falls
  through to:

      access_key_id:     [{:awscli, "default"}, {:system, "AWS_ACCESS_KEY_ID"},     :instance_role, :ecs_task_role]
      secret_access_key: [{:awscli, "default"}, {:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role, :ecs_task_role]
      security_token:    [{:awscli, "default"}, {:system, "AWS_SESSION_TOKEN"},     :instance_role, :ecs_task_role]
      region:            [{:awscli, "default"}, {:system, "AWS_REGION"}, {:system, "AWS_DEFAULT_REGION"}, "us-east-1"]

  The `"default"` profile from `~/.aws/credentials` / `~/.aws/config`
  is tried first. If the profile is absent or the file doesn't exist,
  the source yields `nil` and the chain falls through to env vars and
  instance/task roles. Callers who want a different profile name can
  override at the call site (`access_key_id: {:awscli, "prod"}`) or via
  app env.

  ## Precedence

  **Per-call overrides > app env > built-in defaults.** Caller opts
  replace app-env entries field-by-field. A caller passing
  `access_key_id: "X"` ignores any app-env `:access_key_id` list.
  """

  alias AWS.AuthCache

  @app :aws

  @credential_keys [:access_key_id, :secret_access_key, :security_token, :region]

  @instance_role_keys [:access_key_id, :secret_access_key, :security_token]
  @ecs_keys [:access_key_id, :secret_access_key, :security_token]
  @awscli_keys [:access_key_id, :secret_access_key, :security_token, :region]

  @default_sandbox_credentials [
    access_key_id: "test",
    secret_access_key: "test",
    security_token: "test"
  ]

  @doc """
  Builds a fully-resolved config map for `service`, running the source
  chain for each credential / region key.

  `opts` is the caller's per-call keyword list. Supported credential
  keys: `:access_key_id`, `:secret_access_key`, `:security_token`,
  `:region` (each accepting a literal / source / list). All other
  keys in `opts` flow through unchanged to the underlying source
  fetchers (`:http`, `:home_dir`, `:endpoint`, `:endpoints`,
  `:profile`).
  """
  @spec new(atom, keyword) :: map
  def new(service, opts) when is_atom(service) and is_list(opts) do
    service
    |> build_base(Map.new(Keyword.take(opts, @credential_keys)))
    |> retrieve_runtime_config(opts)
  end

  @doc """
  Merges `overrides` on top of the app-env credential config on top of
  the built-in defaults, returning a map whose values are still
  unresolved (literals / sources / lists).

  `service` is currently unused but reserved for per-service
  overrides (matches the ex_aws signature).
  """
  @spec build_base(atom, map) :: map
  def build_base(_service, overrides) when is_map(overrides) do
    app_env =
      @app
      |> Application.get_all_env()
      |> Map.new()
      |> Map.take(@credential_keys)

    default_credentials()
    |> Map.merge(app_env)
    |> Map.merge(overrides)
  end

  @doc """
  Resolves every value in `config` against its source chain, returning
  a map with literal resolved values. Map-returning sources are merged
  into the outer config so a single source (e.g. `:instance_role`) can
  populate `:access_key_id`, `:secret_access_key`, and
  `:security_token` at once.
  """
  @spec retrieve_runtime_config(map, keyword) :: map
  def retrieve_runtime_config(config, opts) when is_map(config) and is_list(opts) do
    Enum.reduce(config, config, fn {k, v}, acc ->
      case retrieve_runtime_value(v, acc, opts) do
        %{} = result ->
          Map.merge(acc, result)

        nil ->
          # Don't overwrite a key that an earlier map-returning source
          # already populated. Leave whatever the accumulator has.
          if is_nil(Map.get(acc, k)) or acc[k] === v,
            do: Map.put(acc, k, nil),
            else: acc

        value ->
          Map.put(acc, k, value)
      end
    end)
  end

  @doc """
  Resolves a single source `value` to its literal form (or a map, for
  sources that return one). `opts` flows through to the fetchers
  (AuthCache → IMDS / ECS / Profile).

  Returns `nil` when the source yields nothing.
  """
  @spec retrieve_runtime_value(term, map, keyword) :: term | map | nil
  def retrieve_runtime_value(value, config, opts)

  def retrieve_runtime_value({:system, env_var}, _config, _opts) do
    present(System.get_env(env_var))
  end

  def retrieve_runtime_value(:instance_role, _config, opts) do
    :aws_instance_auth
    |> AuthCache.get(opts)
    |> creds_from_cache()
    |> take_keys(@instance_role_keys)
  end

  def retrieve_runtime_value(:ecs_task_role, _config, opts) do
    :aws_ecs_auth
    |> AuthCache.get(opts)
    |> creds_from_cache()
    |> take_keys(@ecs_keys)
  end

  def retrieve_runtime_value({:awscli, profile}, config, opts) do
    retrieve_runtime_value({:awscli, profile, 30}, config, opts)
  end

  def retrieve_runtime_value({:awscli, profile, ttl_seconds}, _config, opts) do
    awscli_opts = Keyword.put(opts, :ttl_seconds, ttl_seconds)

    {:awscli, profile}
    |> AuthCache.get(awscli_opts)
    |> creds_from_cache()
    |> take_keys(@awscli_keys)
  end

  def retrieve_runtime_value(values, config, opts) when is_list(values) do
    Enum.find_value(values, &retrieve_runtime_value(&1, config, opts))
  end

  def retrieve_runtime_value(module, config, opts) when is_atom(module) and not is_nil(module) do
    cond do
      module in [true, false] -> module
      function_exported?(module, :resolve, 2) -> module.resolve(config, opts)
      true -> module
    end
  end

  def retrieve_runtime_value(value, _config, _opts), do: value

  @doc """
  The resolved default region. Runs the region source chain (per-call
  overrides → app env → `AWS_REGION` → `AWS_DEFAULT_REGION` →
  `"us-east-1"`).
  """
  @spec region() :: String.t()
  @spec region(keyword) :: String.t()
  def region(opts \\ []) do
    creds = default_credentials()
    chain = Application.get_env(@app, :region) || creds.region

    case retrieve_runtime_value(chain, %{}, opts) do
      region when is_binary(region) -> region
      _ -> "us-east-1"
    end
  end

  @doc """
  Static sandbox credentials for LocalStack or similar local emulators.
  """
  @spec sandbox_credentials() :: keyword()
  def sandbox_credentials do
    Application.get_env(@app, :sandbox_credentials) || @default_sandbox_credentials
  end

  @doc """
  Merges `sandbox_credentials/0` into `opts` without overwriting caller-supplied keys.
  """
  @spec put_sandbox_credentials(keyword()) :: keyword()
  def put_sandbox_credentials(opts) do
    merge_new(opts, sandbox_credentials())
  end

  def sandbox_enabled? do
    Application.get_env(@app, :sandbox_enabled) || false
  end

  def sandbox_mode do
    Application.get_env(@app, :sandbox_mode) || :local
  end

  def sandbox_scheme do
    Application.get_env(@app, :sandbox_scheme) || "http://"
  end

  def sandbox_host do
    Application.get_env(@app, :sandbox_host) || "localhost"
  end

  def sandbox_port do
    Application.get_env(@app, :sandbox_port) || 4566
  end

  # ---------------------------------------------------------------------------

  defp default_credentials do
    default_profile = {:awscli, System.get_env("AWS_PROFILE") || "default"}

    %{
      access_key_id: [
        default_profile,
        {:system, "AWS_ACCESS_KEY_ID"},
        :instance_role,
        :ecs_task_role
      ],
      secret_access_key: [
        default_profile,
        {:system, "AWS_SECRET_ACCESS_KEY"},
        :instance_role,
        :ecs_task_role
      ],
      security_token: [
        default_profile,
        {:system, "AWS_SESSION_TOKEN"},
        :instance_role,
        :ecs_task_role
      ],
      region: [
        default_profile,
        {:system, "AWS_REGION"},
        {:system, "AWS_DEFAULT_REGION"},
        "us-east-1"
      ]
    }
  end

  # ---------------------------------------------------------------------------

  defp creds_from_cache({:ok, creds}), do: creds
  defp creds_from_cache({:error, _reason}), do: nil

  defp take_keys(nil, _keys), do: nil

  defp take_keys(map, keys) when is_map(map) do
    map
    |> Map.take(keys)
    |> drop_nil_values()
    |> valid_map_or_nil()
  end

  defp drop_nil_values(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp valid_map_or_nil(map) when map_size(map) === 0, do: nil
  defp valid_map_or_nil(map), do: map

  defp present(nil), do: nil
  defp present(""), do: nil
  defp present(value) when is_binary(value), do: value

  defp merge_new(opts, extras) do
    Enum.reduce(extras, opts, fn {k, v}, acc ->
      Keyword.put_new(acc, k, v)
    end)
  end
end
