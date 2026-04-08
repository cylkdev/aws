defmodule AWS.CloudWatch.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.CloudWatch
  alias AWS.CloudWatch.Sandbox

  @sandbox_opts [sandbox: [enabled: true, mode: :inline]]

  # Alarms

  describe "put_metric_alarm/9" do
    test "returns mocked success" do
      Sandbox.set_put_metric_alarm_responses([
        {"webhook-failures", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} =
               CloudWatch.put_metric_alarm(
                 "webhook-failures", "GreaterThanThreshold", 1,
                 "FailedInvocations", "AWS/Events", 300, 0, "Sum",
                 @sandbox_opts
               )
    end
  end

  describe "describe_alarms/1" do
    test "returns mocked alarm list" do
      Sandbox.set_describe_alarms_responses([
        fn -> {:ok, %{metric_alarms: [%{alarm_name: "test"}], next_token: nil}} end
      ])

      assert {:ok, %{metric_alarms: [%{alarm_name: "test"}]}} =
               CloudWatch.describe_alarms(@sandbox_opts)
    end
  end

  describe "describe_alarms_for_metric/3" do
    test "returns mocked alarms for metric" do
      Sandbox.set_describe_alarms_for_metric_responses([
        {"FailedInvocations", fn -> {:ok, %{metric_alarms: []}} end}
      ])

      assert {:ok, %{metric_alarms: []}} =
               CloudWatch.describe_alarms_for_metric("FailedInvocations", "AWS/Events", @sandbox_opts)
    end
  end

  describe "describe_alarm_history/1" do
    test "returns mocked history" do
      Sandbox.set_describe_alarm_history_responses([
        fn -> {:ok, %{alarm_history_items: []}} end
      ])

      assert {:ok, %{alarm_history_items: []}} =
               CloudWatch.describe_alarm_history(@sandbox_opts)
    end
  end

  describe "delete_alarms/2" do
    test "returns success" do
      Sandbox.set_delete_alarms_responses([
        fn -> {:ok, %{}} end
      ])

      assert {:ok, %{}} = CloudWatch.delete_alarms(["webhook-failures"], @sandbox_opts)
    end
  end

  describe "enable_alarm_actions/2" do
    test "returns success" do
      Sandbox.set_enable_alarm_actions_responses([
        fn -> {:ok, %{}} end
      ])

      assert {:ok, %{}} = CloudWatch.enable_alarm_actions(["webhook-failures"], @sandbox_opts)
    end
  end

  describe "disable_alarm_actions/2" do
    test "returns success" do
      Sandbox.set_disable_alarm_actions_responses([
        fn -> {:ok, %{}} end
      ])

      assert {:ok, %{}} = CloudWatch.disable_alarm_actions(["webhook-failures"], @sandbox_opts)
    end
  end

  # Metrics

  describe "get_metric_statistics/6" do
    test "returns mocked statistics" do
      Sandbox.set_get_metric_statistics_responses([
        {"AWS/Events", fn -> {:ok, %{datapoints: [], label: "Invocations"}} end}
      ])

      assert {:ok, %{label: "Invocations"}} =
               CloudWatch.get_metric_statistics(
                 "AWS/Events", "Invocations",
                 "2026-03-01T00:00:00Z", "2026-03-02T00:00:00Z", 300,
                 @sandbox_opts
               )
    end
  end

  describe "list_metrics/1" do
    test "returns mocked metric list" do
      Sandbox.set_list_metrics_responses([
        fn -> {:ok, %{metrics: [%{metric_name: "Invocations"}]}} end
      ])

      assert {:ok, %{metrics: [%{metric_name: "Invocations"}]}} =
               CloudWatch.list_metrics(@sandbox_opts)
    end
  end

  describe "put_metric_data/3" do
    test "returns success" do
      Sandbox.set_put_metric_data_responses([
        {"MyApp", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} =
               CloudWatch.put_metric_data(
                 [%{metric_name: "CustomMetric", value: 1.0, unit: "Count"}],
                 "MyApp",
                 @sandbox_opts
               )
    end
  end

  # Dashboards

  describe "put_dashboard/3" do
    test "returns mocked validation messages" do
      Sandbox.set_put_dashboard_responses([
        {"my-dashboard", fn -> {:ok, %{dashboard_validation_messages: []}} end}
      ])

      assert {:ok, %{dashboard_validation_messages: []}} =
               CloudWatch.put_dashboard("my-dashboard", "{}", @sandbox_opts)
    end
  end

  describe "get_dashboard/2" do
    test "returns mocked dashboard" do
      Sandbox.set_get_dashboard_responses([
        {"my-dashboard", fn -> {:ok, %{dashboard_name: "my-dashboard", dashboard_body: "{}"}} end}
      ])

      assert {:ok, %{dashboard_name: "my-dashboard"}} =
               CloudWatch.get_dashboard("my-dashboard", @sandbox_opts)
    end
  end

  describe "list_dashboards/1" do
    test "returns mocked dashboard list" do
      Sandbox.set_list_dashboards_responses([
        fn -> {:ok, %{dashboard_entries: [%{dashboard_name: "my-dashboard"}]}} end
      ])

      assert {:ok, %{dashboard_entries: [%{dashboard_name: "my-dashboard"}]}} =
               CloudWatch.list_dashboards(@sandbox_opts)
    end
  end

  describe "delete_dashboards/2" do
    test "returns success" do
      Sandbox.set_delete_dashboards_responses([
        fn -> {:ok, %{}} end
      ])

      assert {:ok, %{}} = CloudWatch.delete_dashboards(["my-dashboard"], @sandbox_opts)
    end
  end
end
