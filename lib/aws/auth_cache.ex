defmodule AWS.AuthCache do
  @moduledoc """
  ETS-backed credential cache for the runtime-resolved sources consumed
  by `AWS.Config`: `:instance_role`, `:ecs_task_role`, and
  `{:awscli, profile, ttl}`.

  Port of `ExAws.Config.AuthCache`. Keys:

    * `:aws_instance_auth` — EC2 IMDSv2 credentials.
    * `:aws_ecs_auth` — ECS container credentials.
    * `{:awscli, profile_name}` — shared-profile dispatch (static /
      SSO / credential_process / assume_role).

  Cached entries carry an `:expires_at` when the source provides one.
  Subsequent `get/2` calls return the cached map until the entry
  enters the refresh window (60s before expiry), after which the
  fetcher runs again.

  Negative results are also cached for `@error_ttl_seconds` (5s) to
  prevent the credential chain from hammering the underlying fetcher:
  a single `Config.new/1` call resolves four keys (access key id,
  secret, token, region) and would otherwise trigger four identical
  fetches per failure (four `aws configure export-credentials` shell
  outs, four IMDS timeouts, etc.). The TTL is short enough that
  transient failures recover quickly on the next request.

  `opts[:ttl_seconds]` caps the cache lifetime regardless of
  `:expires_at` (used by `{:awscli, _, ttl}` sources). The remaining
  keys in `opts` are forwarded verbatim to the fetcher (`:http`,
  `:home_dir`, `:endpoint`, `:endpoints`) so caller-supplied overrides
  reach the HTTP and profile layers without being silently discarded.
  """

  use GenServer

  require Logger

  alias AWS.Credentials.Profile
  alias AWS.Credentials.Providers.{ECS, IMDS}

  @table :aws_auth_cache
  @refresh_skew_seconds 60
  @error_ttl_seconds 5

  @type key :: :aws_instance_auth | :aws_ecs_auth | {:awscli, String.t()}
  @type creds :: %{optional(atom) => term}

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Returns the cached credentials for `key`, running the fetcher on
  miss or when the cached entry is in the refresh window. Returns
  `{:error, reason}` when the fetcher fails.

  `opts` is forwarded to the fetcher. `opts[:ttl_seconds]` caps the
  cache lifetime regardless of `:expires_at`.
  """
  @spec get(key, keyword) :: {:ok, creds} | {:error, term}
  def get(key, opts) do
    case lookup(key) do
      :error ->
        refresh(key, opts)

      {:ok, entry} ->
        if fresh?(entry, opts[:ttl_seconds]) do
          replay(entry)
        else
          refresh(key, opts)
        end
    end
  end

  defp replay(%{error: reason}), do: {:error, reason}
  defp replay(%{creds: creds}), do: {:ok, creds}

  @doc "Evicts the entry for `key`."
  @spec invalidate(key) :: :ok
  def invalidate(key) do
    if Process.whereis(__MODULE__) do
      GenServer.call(__MODULE__, {:delete, key})
    else
      :ok
    end
  end

  # ---

  defp lookup(key) do
    case :ets.whereis(@table) do
      :undefined ->
        :error

      _ ->
        case :ets.lookup(@table, key) do
          [{^key, entry}] -> {:ok, entry}
          [] -> :error
        end
    end
  end

  defp fresh?(%{error: _, cached_at: cached_at}, _ttl_seconds) do
    System.monotonic_time(:second) - cached_at < @error_ttl_seconds
  end

  defp fresh?(%{expires_at: %DateTime{} = expires_at}, _ttl_seconds) do
    DateTime.diff(expires_at, DateTime.utc_now(), :second) > @refresh_skew_seconds
  end

  defp fresh?(%{cached_at: cached_at}, ttl_seconds) when is_integer(ttl_seconds) do
    System.monotonic_time(:second) - cached_at < ttl_seconds
  end

  defp fresh?(_entry, _ttl_seconds), do: true

  defp refresh(key, opts) do
    case fetch(key, opts) do
      {:ok, creds} ->
        with :ok <- put_creds(key, creds) do
          {:ok, creds}
        end

      {:error, reason} ->
        log_failure(key, reason)
        _ = put_error(key, reason)
        {:error, reason}

      :skip ->
        _ = put_error(key, :unavailable)
        {:error, :unavailable}
    end
  end

  # Logs once per cache miss + real failure. `:skip` is intentionally
  # silent: it just means a provider doesn't apply (no profile, no
  # IMDS, no ECS env vars). Benign per-source failure shapes are
  # filtered out so a non-EC2 dev box doesn't spam the log every time
  # IMDS times out.
  defp log_failure(key, reason) do
    if loggable?(key, reason) do
      Logger.warning(
        "[AWS.AuthCache] credential source #{inspect(key)} failed: " <>
          "#{inspect(reason)} — continuing chain"
      )
    end
  end

  defp loggable?({:awscli, _}, {:profile_not_found, _}), do: false
  defp loggable?(:aws_instance_auth, {:imds_transport_error, _}), do: false
  defp loggable?(:aws_instance_auth, :imds_no_role), do: false
  defp loggable?(_key, _reason), do: true

  defp put_creds(key, creds) do
    entry = %{
      creds: creds,
      expires_at: Map.get(creds, :expires_at),
      cached_at: System.monotonic_time(:second)
    }

    GenServer.call(__MODULE__, {:put, key, entry})
  end

  defp put_error(key, reason) do
    entry = %{
      error: reason,
      cached_at: System.monotonic_time(:second)
    }

    GenServer.call(__MODULE__, {:put, key, entry})
  end

  defp fetch(:aws_instance_auth, opts), do: IMDS.resolve(opts)
  defp fetch(:aws_ecs_auth, opts), do: ECS.resolve(opts)
  defp fetch({:awscli, profile}, opts), do: Profile.security_credentials(profile, opts)

  # -- GenServer ---------------------------------------------------------------

  @impl GenServer
  def init(:ok) do
    table =
      case :ets.whereis(@table) do
        :undefined -> :ets.new(@table, [:named_table, :protected, :set, read_concurrency: true])
        tid -> tid
      end

    {:ok, %{table: table}}
  end

  @impl GenServer
  def handle_call({:put, key, entry}, _from, state) do
    :ets.insert(state.table, {key, entry})
    {:reply, :ok, state}
  end

  def handle_call({:delete, key}, _from, state) do
    :ets.delete(state.table, key)
    {:reply, :ok, state}
  end
end
