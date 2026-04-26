defmodule AWS.TestCowboyServer do
  @moduledoc """
  Tiny Cowboy-backed HTTP server for unit-testing HTTP client code.

  Usage (inside a test module):

      setup do
        {:ok, port} = AWS.TestCowboyServer.start(fn req ->
          {:ok, body, req} = :cowboy_req.read_body(req)
          :cowboy_req.reply(200, %{"content-type" => "text/plain"}, body, req)
        end)

        on_exit(fn -> AWS.TestCowboyServer.stop() end)
        %{port: port}
      end

  The handler receives a `:cowboy_req` request and must return a
  `:cowboy_req` response (via `:cowboy_req.reply/4` or friends).
  """

  @behaviour :cowboy_handler

  @listener :aws_test_cowboy_listener
  @handler_key {__MODULE__, :handler}

  @doc """
  Starts the listener on an ephemeral port and registers `handler_fun`
  as the request handler. Returns `{:ok, port}`.
  """
  @spec start((:cowboy_req.req() -> :cowboy_req.req())) :: {:ok, pos_integer()}
  def start(handler_fun) when is_function(handler_fun, 1) do
    :persistent_term.put(@handler_key, handler_fun)

    dispatch = :cowboy_router.compile([{:_, [{:_, __MODULE__, []}]}])

    {:ok, _pid} =
      :cowboy.start_clear(
        @listener,
        [{:port, 0}],
        %{env: %{dispatch: dispatch}}
      )

    {:ok, :ranch.get_port(@listener)}
  end

  @doc "Replaces the handler without restarting the listener."
  @spec set_handler((:cowboy_req.req() -> :cowboy_req.req())) :: :ok
  def set_handler(handler_fun) when is_function(handler_fun, 1) do
    :persistent_term.put(@handler_key, handler_fun)
  end

  @doc "Stops the listener started by `start/1`."
  def stop do
    _ = :cowboy.stop_listener(@listener)
    :persistent_term.erase(@handler_key)
    :ok
  end

  @impl :cowboy_handler
  def init(req, state) do
    handler = :persistent_term.get(@handler_key)
    req = handler.(req)
    {:ok, req, state}
  end
end
