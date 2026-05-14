defmodule AWS.ClientTest do
  use ExUnit.Case

  alias AWS.Client
  alias AWS.EventBridge.Operation, as: EventOperation
  alias AWS.S3.Operation, as: S3Operation
  alias AWS.TestCowboyServer

  @pinned_now ~U[2025-01-15 12:00:00Z]
  @creds %{
    access_key_id: "AKIDEXAMPLE",
    secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    region: "us-east-1",
    service: "events"
  }

  setup_all do
    {:ok, port} = TestCowboyServer.start(fn req -> :cowboy_req.reply(200, req) end)
    on_exit(fn -> TestCowboyServer.stop() end)
    %{port: port, base: "http://127.0.0.1:#{port}"}
  end

  @default_http %{url: "http://127.0.0.1/", headers: [], body: ""}

  defp event_op(overrides) do
    @creds
    |> Map.merge(@default_http)
    |> Map.put(:method, :post)
    |> Map.merge(Map.new(overrides))
    |> then(&struct!(EventOperation, &1))
  end

  defp s3_op(overrides) do
    @creds
    |> Map.merge(@default_http)
    |> Map.put(:method, :put)
    |> Map.merge(Map.new(overrides))
    |> then(&struct!(S3Operation, &1))
  end

  describe "execute/1" do
    test "signs and POSTs a buffered body; server sees SigV4 authorization", %{base: base} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:auth, :cowboy_req.header("authorization", req)})
        send(test_pid, {:content_sha, :cowboy_req.header("x-amz-content-sha256", req)})
        :cowboy_req.reply(200, %{"content-type" => "text/plain"}, "ok", req)
      end)

      op =
        event_op(url: base <> "/", headers: [{"content-type", "text/plain"}], body: "{}")

      assert {:ok, %{status_code: 200, body: "ok"}} = Client.execute(op)

      assert_receive {:auth, "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/" <> _}
      assert_receive {:content_sha, hash}
      assert is_binary(hash)
    end

    test "returns {:error, {:http_error, 500, body}} for a 500 response", %{base: base} do
      TestCowboyServer.set_handler(fn req ->
        :cowboy_req.reply(500, %{}, "internal error", req)
      end)

      op = event_op(url: base <> "/")

      assert {:error, {:http_error, 500, "internal error"}} = Client.execute(op)
    end

    test "returns {:error, reason} on connect failure" do
      op = event_op(url: "http://127.0.0.1:1/", http: [connect_timeout: 500])

      assert {:error, reason} = Client.execute(op)
      refute match?({:http_error, _, _}, reason)
    end

    test ":payload_hash override appears in x-amz-content-sha256", %{base: base} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:sha, :cowboy_req.header("x-amz-content-sha256", req)})
        :cowboy_req.reply(200, req)
      end)

      op =
        s3_op(
          method: :put,
          url: base <> "/",
          body: "ignored",
          payload_hash: "UNSIGNED-PAYLOAD"
        )

      assert {:ok, %{status_code: 200}} = Client.execute(op)
      assert_receive {:sha, "UNSIGNED-PAYLOAD"}
    end

    test ":now override produces a deterministic signature", %{base: base} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:auth, :cowboy_req.header("authorization", req)})
        :cowboy_req.reply(200, req)
      end)

      op = [url: base <> "/"] |> event_op() |> Map.put(:now, @pinned_now)

      assert {:ok, _} = Client.execute(op)
      assert_receive {:auth, auth1}

      assert {:ok, _} = Client.execute(op)
      assert_receive {:auth, auth2}

      assert auth1 === auth2
      assert auth1 =~ "20250115/us-east-1/events/aws4_request"
    end

    test ":security_token is added as x-amz-security-token header", %{base: base} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:token, :cowboy_req.header("x-amz-security-token", req)})
        :cowboy_req.reply(200, req)
      end)

      op = event_op(url: base <> "/", security_token: "session-xyz")

      assert {:ok, _} = Client.execute(op)
      assert_receive {:token, "session-xyz"}
    end

    test ":stream_upload: true dispatches to stream_upload", %{base: base} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req, %{length: 10_000_000})
        send(test_pid, {:body, body})
        :cowboy_req.reply(200, %{}, "ok", req)
      end)

      chunks = ["hello ", "streamed ", "world"]
      expected = IO.iodata_to_binary(chunks)
      content_length = expected |> byte_size() |> Integer.to_string()

      op =
        s3_op(
          method: :put,
          url: base <> "/upload",
          headers: [{"content-length", content_length}],
          body: chunks,
          stream_upload: true,
          payload_hash: "UNSIGNED-PAYLOAD"
        )

      assert {:ok, %{status_code: 200}} = Client.execute(op)
      assert_receive {:body, ^expected}
    end

    test ":stream_response: true returns body_stream", %{base: base} do
      TestCowboyServer.set_handler(fn req ->
        req = :cowboy_req.stream_reply(200, %{"content-type" => "text/plain"}, req)
        :ok = :cowboy_req.stream_body("part-A ", :nofin, req)
        :ok = :cowboy_req.stream_body("part-B", :fin, req)
        req
      end)

      op = s3_op(method: :get, url: base <> "/", stream_response: true)

      assert {:ok, %{status_code: 200, body_stream: stream}} = Client.execute(op)
      full = stream |> Enum.to_list() |> IO.iodata_to_binary()
      assert full === "part-A part-B"
    end

    test ":stream_response with non-2xx drains stream into an error body", %{base: base} do
      TestCowboyServer.set_handler(fn req ->
        req = :cowboy_req.stream_reply(500, %{}, req)
        :ok = :cowboy_req.stream_body("oh ", :nofin, req)
        :ok = :cowboy_req.stream_body("no", :fin, req)
        req
      end)

      op = s3_op(method: :get, url: base <> "/", stream_response: true)

      assert {:error, {:http_error, 500, "oh no"}} = Client.execute(op)
    end
  end

  describe "resolve_config/4" do
    # Most of these tests don't exercise credential resolution; they just
    # verify that endpoint / region / namespace wiring is correct. Provide
    # static creds as top-level opts so `resolve_config/4` resolves without
    # hitting the full provider chain (which would otherwise try IMDS and
    # time out).
    @static_creds [access_key_id: "AK", secret_access_key: "SK"]

    test "picks region from top-level opts, else Config.region()" do
      assert {:ok, %{region: "eu-west-2"}} =
               Client.resolve_config(
                 :events,
                 @static_creds ++ [region: "eu-west-2"],
                 fn _ -> "h" end
               )

      assert {:ok, %{region: "ap-south-1"}} =
               Client.resolve_config(
                 :events,
                 @static_creds ++ [region: "ap-south-1"],
                 fn _ -> "h" end
               )

      assert {:ok, %{region: default_region}} =
               Client.resolve_config(:events, @static_creds, fn _ -> "h" end)

      assert default_region === AWS.Config.region()
    end

    test "uses default_host_fn when no :host override is given" do
      assert {:ok, %{host: "events.us-east-1.amazonaws.com"}} =
               Client.resolve_config(
                 :events,
                 @static_creds ++ [region: "us-east-1"],
                 &"events.#{&1}.amazonaws.com"
               )
    end

    test "namespace :host / :scheme / :port override the defaults" do
      assert {:ok, %{scheme: "http", host: "localhost", port: 4566}} =
               Client.resolve_config(
                 :events,
                 @static_creds ++ [events: [scheme: "http", host: "localhost", port: 4566]],
                 fn _ -> "never" end
               )
    end

    test "top-level :access_key_id + :secret_access_key + :security_token resolve" do
      assert {:ok, %{access_key_id: "ABC", secret_access_key: "SEC", security_token: "TOK"}} =
               Client.resolve_config(
                 :events,
                 [
                   access_key_id: "ABC",
                   secret_access_key: "SEC",
                   security_token: "TOK"
                 ],
                 fn _ -> "h" end
               )
    end

    test "host always comes from default_host_fn regardless of sandbox opts" do
      assert {:ok, %{host: "explicit.example.com"}} =
               Client.resolve_config(
                 :events,
                 @static_creds ++ [sandbox: [enabled: true]],
                 fn _ -> "explicit.example.com" end
               )
    end

    test "extra keys are merged from namespace opts" do
      assert {:ok, %{path_style: true}} =
               Client.resolve_config(
                 :s3,
                 @static_creds ++ [s3: [path_style: true]],
                 fn _ -> "h" end,
                 [:path_style]
               )

      assert {:ok, %{path_style: nil}} =
               Client.resolve_config(:s3, @static_creds, fn _ -> "h" end, [:path_style])
    end
  end

  describe "simple_url/1" do
    test "omits port for http/80 and https/443" do
      assert Client.simple_url(%{scheme: "http", host: "h", port: 80}) === "http://h/"
      assert Client.simple_url(%{scheme: "https", host: "h", port: 443}) === "https://h/"
      assert Client.simple_url(%{scheme: "https", host: "h", port: nil}) === "https://h/"
    end

    test "emits :{port} for non-default ports" do
      assert Client.simple_url(%{scheme: "http", host: "h", port: 4566}) === "http://h:4566/"
      assert Client.simple_url(%{scheme: "https", host: "h", port: 8443}) === "https://h:8443/"
    end
  end
end
