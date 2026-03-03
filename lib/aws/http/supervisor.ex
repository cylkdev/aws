defmodule AWS.HTTP.Supervisor do
  use Supervisor

  @name AWS.HTTP

  @default_finch_pools %{
    default: [
      size: 32,
      count: 8,
      pool_max_idle_time: 120_000,
      conn_max_idle_time: 60_000,
      conn_opts: [
        protocols: [:http1],
        transport_opts: [
          timeout: 20_000,
          keepalive: true
        ]
      ]
    ]
  }

  @finch_name AWS.HTTP.Finch
  @default_finch_options [
    name: @finch_name,
    pools: @default_finch_pools
  ]

  def finch_name, do: @finch_name

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, Keyword.put(opts, :name, @name))
  end

  def child_spec(opts \\ []) do
    %{
      id: @name,
      start: {__MODULE__, :start_link, [opts]},
      restart: Keyword.get(opts, :restart, :permanent),
      shutdown: Keyword.get(opts, :shutdown, 5000),
      type: :supervisor
    }
  end

  @impl true
  def init(opts) do
    children = [
      {Finch, with_finch_opts(opts[:finch] || [])}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp with_finch_opts(opts) do
    @default_finch_options
    |> Keyword.merge(opts)
    |> Keyword.update(:pools, @default_finch_pools, &Map.merge(&1, opts[:pools] || %{}))
  end
end
