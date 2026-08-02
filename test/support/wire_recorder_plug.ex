defmodule AWS.WireRecorderPlug do
  @moduledoc """
  Reports the HTTP method and path of each request it serves back to a test
  process, then replies with a canned response.

  Exists as a module rather than an anonymous function because
  `Plug.Cowboy.Handler` invokes `plug.call(conn, opts)` -- it accepts module
  plugs only.

  Options:

    * `:test` - pid to notify (required)
    * `:tag` - first element of the message tuple, defaults to `:request`
    * `:status` - response status, defaults to `200`
    * `:body` - response body, defaults to `""`
    * `:resp_headers` - list of `{name, value}` response headers

  The message sent is `{tag, method, request_path, query_string}`.
  """

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    send(
      Keyword.fetch!(opts, :test),
      {Keyword.get(opts, :tag, :request), conn.method, conn.request_path, conn.query_string}
    )

    conn
    |> Plug.Conn.merge_resp_headers(Keyword.get(opts, :resp_headers, []))
    |> Plug.Conn.resp(Keyword.get(opts, :status, 200), Keyword.get(opts, :body, ""))
  end
end
