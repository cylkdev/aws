defmodule AWS.AutoScaling.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.AutoScaling
  alias AWS.AutoScaling.Sandbox

  @sandbox_opts [sandbox: [enabled: true, mode: :inline]]

  describe "describe_auto_scaling_groups/1" do
    test "returns a registered list (no key needed; auto-wraps as wildcard)" do
      Sandbox.set_describe_auto_scaling_groups_responses([
        fn ->
          {:ok,
           %{
             auto_scaling_groups: [%{auto_scaling_group_name: "my-asg", instances: []}],
             next_token: nil
           }}
        end
      ])

      assert {:ok, %{auto_scaling_groups: [%{auto_scaling_group_name: "my-asg"}]}} =
               AutoScaling.describe_auto_scaling_groups(@sandbox_opts)
    end
  end

  describe "describe_instance_refreshes/2" do
    test "looks up by ASG name" do
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

      assert {:ok, %{instance_refreshes: [%{instance_refresh_id: "r-1"}]}} =
               AutoScaling.describe_instance_refreshes("my-asg", @sandbox_opts)
    end
  end

  describe "complete_lifecycle_action/1" do
    test "matches by hook|asg key" do
      Sandbox.set_complete_lifecycle_action_responses([
        {"my-hook|my-asg", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} =
               AutoScaling.complete_lifecycle_action(
                 [
                   lifecycle_hook_name: "my-hook",
                   auto_scaling_group_name: "my-asg",
                   lifecycle_action_result: "CONTINUE"
                 ] ++ @sandbox_opts
               )
    end
  end

  describe "set_instance_health/3" do
    test "looks up by instance id and passes inputs to 3-arity fn" do
      Sandbox.set_set_instance_health_responses([
        {"i-aaaa", fn id, status, _opts -> {:ok, %{seen: {id, status}}} end}
      ])

      assert {:ok, %{seen: {"i-aaaa", "Unhealthy"}}} =
               AutoScaling.set_instance_health("i-aaaa", "Unhealthy", @sandbox_opts)
    end
  end

  describe "set_desired_capacity/3" do
    test "looks up by ASG name" do
      Sandbox.set_set_desired_capacity_responses([
        {"my-asg", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = AutoScaling.set_desired_capacity("my-asg", 5, @sandbox_opts)
    end
  end
end
