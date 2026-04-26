defmodule AWS.LogsTest do
  use ExUnit.Case

  alias AWS.Logs
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} = TestCowboyServer.start(fn req -> :cowboy_req.reply(200, req) end)
    on_exit(fn -> TestCowboyServer.stop() end)

    logs_opts = [
      access_key_id: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      logs: [scheme: "http", host: "127.0.0.1", port: port]
    ]

    %{port: port, logs_opts: logs_opts}
  end

  # -- target header + signing --------------------------------------------------

  describe "target header" do
    test "create_log_group sends Logs_20140328.CreateLogGroup", %{logs_opts: logs_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:target, :cowboy_req.header("x-amz-target", req)})
        reply_json(req, 200, %{})
      end)

      assert {:ok, _} = Logs.create_log_group("g", logs_opts)
      assert_receive {:target, "Logs_20140328.CreateLogGroup"}
    end

    test "filter_log_events sends Logs_20140328.FilterLogEvents", %{logs_opts: logs_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:target, :cowboy_req.header("x-amz-target", req)})
        reply_json(req, 200, %{"events" => [], "nextToken" => nil})
      end)

      assert {:ok, _} = Logs.filter_log_events("g", logs_opts)
      assert_receive {:target, "Logs_20140328.FilterLogEvents"}
    end

    test "includes SigV4 authorization header", %{logs_opts: logs_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:auth, :cowboy_req.header("authorization", req)})
        reply_json(req, 200, %{})
      end)

      assert {:ok, _} = Logs.create_log_group("g", logs_opts)
      assert_receive {:auth, "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/" <> _}
    end
  end

  # -- request body --------------------------------------------------------------

  describe "request body encoding" do
    test "create_log_group encodes logGroupName (camelCase)", %{logs_opts: logs_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, :json.decode(body)})
        reply_json(req, 200, %{})
      end)

      assert {:ok, _} =
               Logs.create_log_group(
                 "my-group",
                 logs_opts ++ [kms_key_id: "arn:aws:kms:us-east-1:111:key/abc"]
               )

      assert_receive {:body, body}
      assert body["logGroupName"] === "my-group"
      assert body["kmsKeyId"] === "arn:aws:kms:us-east-1:111:key/abc"
    end

    test "put_log_events camelizes event entry keys", %{logs_opts: logs_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, :json.decode(body)})
        reply_json(req, 200, %{})
      end)

      events = [%{timestamp: 1_700_000_000_000, message: "hello"}]

      assert {:ok, _} = Logs.put_log_events("g", "s", events, logs_opts)

      assert_receive {:body, body}
      assert [%{"timestamp" => 1_700_000_000_000, "message" => "hello"}] = body["logEvents"]
      assert body["logGroupName"] === "g"
      assert body["logStreamName"] === "s"
    end

    test "empty body for no-arg ops is {}", %{logs_opts: logs_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:raw_body, body})
        reply_json(req, 200, %{"logGroups" => [], "nextToken" => nil})
      end)

      assert {:ok, _} = Logs.describe_log_groups(logs_opts)
      assert_receive {:raw_body, "{}"}
    end
  end

  # -- response deserialization --------------------------------------------------

  describe "response deserialization" do
    test "2xx body is decoded and snake-cased", %{logs_opts: logs_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 200, %{
          "logGroups" => [%{"logGroupName" => "g1", "retentionInDays" => 30}]
        })
      end)

      assert {:ok,
              %{
                log_groups: [%{log_group_name: "g1", retention_in_days: 30}]
              }} = Logs.describe_log_groups(logs_opts)
    end

    test "empty 200 body decodes to empty map", %{logs_opts: logs_opts} do
      TestCowboyServer.set_handler(fn req -> :cowboy_req.reply(200, req) end)

      assert {:ok, %{}} = Logs.delete_log_group("g", logs_opts)
    end
  end

  # -- error paths ---------------------------------------------------------------

  describe "error paths" do
    test "4xx maps to ErrorMessage with :not_found code", %{logs_opts: logs_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 400, %{
          "__type" => "ResourceNotFoundException",
          "message" => "The specified log group does not exist."
        })
      end)

      assert {:error, %ErrorMessage{code: :not_found}} =
               Logs.describe_log_streams("missing", logs_opts)
    end

    test "5xx maps to ErrorMessage with :service_unavailable code", %{logs_opts: logs_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 500, %{"__type" => "InternalFailure"})
      end)

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               Logs.describe_log_streams("g", logs_opts)
    end

    test "transport error maps to ErrorMessage with :internal_server_error code" do
      # Port 1 is reserved; connect fails within the timeout.
      bad_opts = [
        scheme: "http",
        host: "127.0.0.1",
        port: 1,
        access_key_id: "AKIA",
        secret_access_key: "secret"
      ]

      assert {:error, %ErrorMessage{code: :internal_server_error}} =
               Logs.create_log_group("g", logs: bad_opts, http: [connect_timeout: 500])
    end
  end

  # -- helpers -------------------------------------------------------------------

  defp reply_json(req, status, map) do
    :cowboy_req.reply(
      status,
      %{"content-type" => "application/x-amz-json-1.1"},
      map |> :json.encode() |> IO.iodata_to_binary(),
      req
    )
  end
end
