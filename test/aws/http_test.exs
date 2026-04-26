defmodule AWS.HTTPTest do
  use ExUnit.Case

  alias AWS.HTTP
  alias AWS.TestCowboyServer

  setup_all do
    {:ok, port} = TestCowboyServer.start(fn req -> :cowboy_req.reply(200, req) end)
    on_exit(fn -> TestCowboyServer.stop() end)
    %{port: port, base: "http://127.0.0.1:#{port}"}
  end

  describe "request/5" do
    test "get request returns {:ok, %{status_code: 200}} and server sees method GET", %{
      base: base
    } do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:method, :cowboy_req.method(req)})
        :cowboy_req.reply(200, %{"content-type" => "text/plain"}, "hello", req)
      end)

      assert {:ok, %{status_code: 200, body: "hello"}} =
               HTTP.request(:get, base <> "/", "", [], [])

      assert_receive {:method, "GET"}
    end

    test "post body is echoed back verbatim", %{base: base} do
      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        :cowboy_req.reply(200, %{"content-type" => "application/octet-stream"}, body, req)
      end)

      payload = ~s({"hello":"world"})

      assert {:ok, %{status_code: 200, body: ^payload}} =
               HTTP.request(:post, base <> "/", payload, [], [])
    end

    test "custom request headers are visible to the server", %{base: base} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:header, :cowboy_req.header("x-custom", req)})
        :cowboy_req.reply(200, req)
      end)

      assert {:ok, %{status_code: 200}} =
               HTTP.request(:post, base <> "/", "", [{"x-custom", "aws-http2"}], [])

      assert_receive {:header, "aws-http2"}
    end

    test "non-2xx status is returned as {:ok, %{status_code: 404}}", %{base: base} do
      TestCowboyServer.set_handler(fn req -> :cowboy_req.reply(404, %{}, "nope", req) end)

      assert {:ok, %{status_code: 404, body: "nope"}} =
               HTTP.request(:get, base <> "/", "", [], [])
    end

    test "empty response body returns body: \"\"", %{base: base} do
      TestCowboyServer.set_handler(fn req -> :cowboy_req.reply(204, req) end)

      assert {:ok, %{status_code: 204, body: ""}} =
               HTTP.request(:get, base <> "/", "", [], [])
    end

    test "connect_timeout on closed port returns {:error, %{reason: _}}" do
      # Port 1 is reserved and unused; connection should fail quickly.
      assert {:error, %{reason: _reason}} =
               HTTP.request(:get, "http://127.0.0.1:1/", "", [], connect_timeout: 500)
    end

    test "request_timeout fires when handler is slow", %{base: base} do
      TestCowboyServer.set_handler(fn req ->
        Process.sleep(300)
        :cowboy_req.reply(200, req)
      end)

      assert {:error, %{reason: _reason}} =
               HTTP.request(:get, base <> "/", "", [], request_timeout: 50)
    end

    test "unsupported scheme raises ArgumentError" do
      assert_raise ArgumentError, ~r/unsupported scheme/, fn ->
        HTTP.request(:get, "ftp://example.com/", "", [], [])
      end
    end

    test "missing host raises ArgumentError" do
      assert_raise ArgumentError, ~r/missing host/, fn ->
        HTTP.request(:get, "http:///path", "", [], [])
      end
    end
  end

  describe "post/4" do
    test "delegates to request/5 with :post", %{base: base} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:method, :cowboy_req.method(req)})
        :cowboy_req.reply(200, req)
      end)

      assert {:ok, %{status_code: 200}} = HTTP.post(base <> "/", "body", [])
      assert_receive {:method, "POST"}
    end
  end

  describe "get/3" do
    test "delegates to request/5 with :get and empty body", %{base: base} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:method, :cowboy_req.method(req)})
        :cowboy_req.reply(200, req)
      end)

      assert {:ok, %{status_code: 200}} = HTTP.get(base <> "/")
      assert_receive {:method, "GET"}
    end
  end

  describe "stream_upload/5" do
    test "full payload arrives at the server when body is an Enumerable", %{base: base} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req, %{length: 10_000_000})
        send(test_pid, {:body, body})
        :cowboy_req.reply(200, %{}, "ok", req)
      end)

      chunks = ["hello", " ", "world", " ", "from", " ", "stream"]
      expected = IO.iodata_to_binary(chunks)

      assert {:ok, %{status_code: 200}} =
               HTTP.stream_upload(
                 :put,
                 base <> "/upload",
                 chunks,
                 [{"content-length", Integer.to_string(byte_size(expected))}],
                 []
               )

      assert_receive {:body, ^expected}
    end

    test "non-2xx status from server is still returned as {:ok, _}", %{base: base} do
      TestCowboyServer.set_handler(fn req ->
        {:ok, _, req} = :cowboy_req.read_body(req)
        :cowboy_req.reply(500, %{}, "boom", req)
      end)

      assert {:ok, %{status_code: 500, body: "boom"}} =
               HTTP.stream_upload(:put, base <> "/", ["a"], [{"content-length", "1"}], [])
    end

    test "connect failure returns {:error, %{reason: _}}" do
      assert {:error, %{reason: _}} =
               HTTP.stream_upload(
                 :put,
                 "http://127.0.0.1:1/",
                 ["x"],
                 [{"content-length", "1"}],
                 connect_timeout: 500
               )
    end
  end

  describe "stream_download/3" do
    test "returns a lazy body_stream that yields server-written chunks", %{base: base} do
      TestCowboyServer.set_handler(fn req ->
        req = :cowboy_req.stream_reply(200, %{"content-type" => "text/plain"}, req)
        :ok = :cowboy_req.stream_body("chunk-1 ", :nofin, req)
        :ok = :cowboy_req.stream_body("chunk-2 ", :nofin, req)
        :ok = :cowboy_req.stream_body("chunk-3", :fin, req)
        req
      end)

      assert {:ok, %{status_code: 200, body_stream: stream}} =
               HTTP.stream_download(base <> "/", [], [])

      full = stream |> Enum.to_list() |> IO.iodata_to_binary()

      assert full === "chunk-1 chunk-2 chunk-3"
    end

    test "connect failure returns {:error, %{reason: _}}" do
      assert {:error, %{reason: _}} =
               HTTP.stream_download("http://127.0.0.1:1/", [], connect_timeout: 500)
    end
  end
end
