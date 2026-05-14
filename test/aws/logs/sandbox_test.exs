defmodule AWS.Logs.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.Logs
  alias AWS.Logs.Sandbox

  @sandbox_opts [sandbox: [enabled: true]]

  # Log Groups

  describe "create_log_group/2" do
    test "returns mocked success" do
      Sandbox.set_create_log_group_responses([
        {"my-group", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = Logs.create_log_group("my-group", @sandbox_opts)
    end
  end

  describe "delete_log_group/2" do
    test "returns mocked success" do
      Sandbox.set_delete_log_group_responses([
        {"my-group", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = Logs.delete_log_group("my-group", @sandbox_opts)
    end
  end

  describe "describe_log_groups/1" do
    test "returns mocked list" do
      Sandbox.set_describe_log_groups_responses([
        fn -> {:ok, %{log_groups: [%{log_group_name: "my-group"}], next_token: nil}} end
      ])

      assert {:ok, %{log_groups: [%{log_group_name: "my-group"}]}} =
               Logs.describe_log_groups(@sandbox_opts)
    end
  end

  describe "put_retention_policy/3" do
    test "returns mocked success" do
      Sandbox.set_put_retention_policy_responses([
        {"my-group", fn days -> {:ok, %{days: days}} end}
      ])

      assert {:ok, %{days: 30}} = Logs.put_retention_policy("my-group", 30, @sandbox_opts)
    end
  end

  describe "delete_retention_policy/2" do
    test "returns mocked success" do
      Sandbox.set_delete_retention_policy_responses([
        {"my-group", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = Logs.delete_retention_policy("my-group", @sandbox_opts)
    end
  end

  # Log Streams

  describe "create_log_stream/3" do
    test "returns mocked success" do
      Sandbox.set_create_log_stream_responses([
        {"my-group", fn stream -> {:ok, %{stream: stream}} end}
      ])

      assert {:ok, %{stream: "my-stream"}} =
               Logs.create_log_stream("my-group", "my-stream", @sandbox_opts)
    end
  end

  describe "delete_log_stream/3" do
    test "returns mocked success" do
      Sandbox.set_delete_log_stream_responses([
        {"my-group", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = Logs.delete_log_stream("my-group", "my-stream", @sandbox_opts)
    end
  end

  describe "describe_log_streams/2" do
    test "returns mocked list" do
      Sandbox.set_describe_log_streams_responses([
        {"my-group", fn -> {:ok, %{log_streams: [%{log_stream_name: "s1"}], next_token: nil}} end}
      ])

      assert {:ok, %{log_streams: [%{log_stream_name: "s1"}]}} =
               Logs.describe_log_streams("my-group", @sandbox_opts)
    end
  end

  # Log Events

  describe "put_log_events/4" do
    test "returns mocked success with events passed through" do
      Sandbox.set_put_log_events_responses([
        {"my-group",
         fn stream, events ->
           {:ok, %{stream: stream, count: length(events)}}
         end}
      ])

      events = [%{timestamp: 1_700_000_000_000, message: "hello"}]

      assert {:ok, %{stream: "my-stream", count: 1}} =
               Logs.put_log_events("my-group", "my-stream", events, @sandbox_opts)
    end
  end

  describe "get_log_events/3" do
    test "returns mocked events" do
      Sandbox.set_get_log_events_responses([
        {"my-group",
         fn stream ->
           {:ok,
            %{
              events: [%{timestamp: 1, message: "m", ingestion_time: 2}],
              next_forward_token: "t",
              stream: stream
            }}
         end}
      ])

      assert {:ok, %{events: [%{message: "m"}], stream: "my-stream"}} =
               Logs.get_log_events("my-group", "my-stream", @sandbox_opts)
    end
  end

  describe "filter_log_events/2" do
    test "returns mocked events" do
      Sandbox.set_filter_log_events_responses([
        {"my-group", fn -> {:ok, %{events: [%{message: "boom"}], next_token: nil}} end}
      ])

      assert {:ok, %{events: [%{message: "boom"}]}} =
               Logs.filter_log_events(
                 "my-group",
                 [filter_pattern: "ERROR"] ++ @sandbox_opts
               )
    end
  end

  # Insights Queries

  describe "start_query/5" do
    test "returns mocked query id" do
      Sandbox.set_start_query_responses([
        {"my-group",
         fn _start, _end_time, query ->
           {:ok, %{query_id: "q-1", echoed: query}}
         end}
      ])

      assert {:ok, %{query_id: "q-1", echoed: "fields @message"}} =
               Logs.start_query("my-group", 1, 2, "fields @message", @sandbox_opts)
    end
  end

  describe "get_query_results/2" do
    test "returns mocked results" do
      Sandbox.set_get_query_results_responses([
        {"q-1", fn -> {:ok, %{status: "Complete", results: []}} end}
      ])

      assert {:ok, %{status: "Complete"}} = Logs.get_query_results("q-1", @sandbox_opts)
    end
  end

  describe "stop_query/2" do
    test "returns mocked success" do
      Sandbox.set_stop_query_responses([
        {"q-1", fn -> {:ok, %{success: true}} end}
      ])

      assert {:ok, %{success: true}} = Logs.stop_query("q-1", @sandbox_opts)
    end
  end

  # Regex matching

  describe "regex matching" do
    test "matches log group name by regex" do
      Sandbox.set_create_log_group_responses([
        {~r/^app-/, fn -> {:ok, %{matched: true}} end}
      ])

      assert {:ok, %{matched: true}} = Logs.create_log_group("app-prod", @sandbox_opts)
    end
  end
end
