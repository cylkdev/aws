defmodule AWS.AutoScaling.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.AutoScaling
  alias AWS.AutoScaling.Sandbox

  describe "describe_auto_scaling_groups/1" do
    test "returns the registered groups" do
      Sandbox.set_describe_auto_scaling_groups_responses([
        fn ->
          {:ok,
           %{
             auto_scaling_groups: [%{auto_scaling_group_name: "my-asg", instances: []}],
             next_token: nil
           }}
        end
      ])

      assert {:ok,
              %{auto_scaling_groups: [%{auto_scaling_group_name: "my-asg"}], next_token: nil}} =
               AutoScaling.describe_auto_scaling_groups(sandbox: [enabled: true])
    end
  end

  describe "describe_instance_refreshes/2" do
    test "returns the refreshes registered for the group" do
      Sandbox.set_describe_instance_refreshes_responses([
        {"my-asg",
         fn ->
           {:ok,
            %{
              instance_refreshes: [%{instance_refresh_id: "r-1", status: "InProgress"}],
              next_token: nil
            }}
         end}
      ])

      assert {:ok, %{instance_refreshes: [%{instance_refresh_id: "r-1", status: "InProgress"}]}} =
               AutoScaling.describe_instance_refreshes("my-asg", sandbox: [enabled: true])
    end
  end

  describe "complete_lifecycle_action/4" do
    test "returns the response registered for the hook and group" do
      Sandbox.set_complete_lifecycle_action_responses([
        {"my-hook|my-asg", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} =
               AutoScaling.complete_lifecycle_action(
                 "my-hook",
                 "my-asg",
                 "CONTINUE",
                 sandbox: [enabled: true]
               )
    end
  end

  describe "record_lifecycle_action_heartbeat/3" do
    test "returns the response registered for the hook and group" do
      Sandbox.set_record_lifecycle_action_heartbeat_responses([
        {"my-hook|my-asg", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} =
               AutoScaling.record_lifecycle_action_heartbeat(
                 "my-hook",
                 "my-asg",
                 sandbox: [enabled: true]
               )
    end
  end

  describe "set_instance_health/3" do
    test "returns the response registered for the instance" do
      Sandbox.set_set_instance_health_responses([{"i-aaaa", fn -> {:ok, %{}} end}])

      assert {:ok, %{}} =
               AutoScaling.set_instance_health("i-aaaa", "Unhealthy", sandbox: [enabled: true])
    end
  end

  describe "set_desired_capacity/3" do
    test "returns the response registered for the group" do
      Sandbox.set_set_desired_capacity_responses([{"my-asg", fn -> {:ok, %{}} end}])

      assert {:ok, %{}} = AutoScaling.set_desired_capacity("my-asg", 5, sandbox: [enabled: true])
    end
  end
end
