defmodule AWS.ElasticLoadBalancingV2.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.ElasticLoadBalancingV2
  alias AWS.ElasticLoadBalancingV2.Sandbox

  @sandbox_opts [sandbox: [enabled: true, mode: :inline]]

  describe "describe_target_groups/1" do
    test "returns a registered list (no key needed; auto-wraps as wildcard)" do
      Sandbox.set_describe_target_groups_responses([
        fn ->
          {:ok,
           %{
             target_groups: [
               %{
                 target_group_arn: "arn:aws:...:targetgroup/my-tg/abc",
                 target_group_name: "my-tg"
               }
             ],
             next_token: nil
           }}
        end
      ])

      assert {:ok, %{target_groups: [%{target_group_name: "my-tg"}]}} =
               ElasticLoadBalancingV2.describe_target_groups(
                 Keyword.put(@sandbox_opts, :names, ["my-tg"])
               )
    end

    test "1-arity function receives the call opts" do
      Sandbox.set_describe_target_groups_responses([
        fn opts -> {:ok, %{target_groups: [], next_token: opts[:names]}} end
      ])

      assert {:ok, %{next_token: ["my-tg"]}} =
               ElasticLoadBalancingV2.describe_target_groups(
                 Keyword.put(@sandbox_opts, :names, ["my-tg"])
               )
    end
  end

  describe "describe_target_health/1" do
    test "returns a registered list (no key needed; auto-wraps as wildcard)" do
      Sandbox.set_describe_target_health_responses([
        fn ->
          {:ok,
           %{
             target_health_descriptions: [
               %{target_id: "i-0abc", port: 4000, state: "healthy"}
             ]
           }}
        end
      ])

      assert {:ok, %{target_health_descriptions: [%{target_id: "i-0abc", state: "healthy"}]}} =
               ElasticLoadBalancingV2.describe_target_health(
                 Keyword.put(@sandbox_opts, :target_group_arn, "arn:...")
               )
    end

    test "1-arity function receives the call opts" do
      Sandbox.set_describe_target_health_responses([
        fn opts ->
          {:ok,
           %{
             target_health_descriptions: [
               %{target_id: opts[:target_group_arn], port: 0, state: "echo"}
             ]
           }}
        end
      ])

      assert {:ok, %{target_health_descriptions: [%{target_id: "arn:echo"}]}} =
               ElasticLoadBalancingV2.describe_target_health(
                 Keyword.put(@sandbox_opts, :target_group_arn, "arn:echo")
               )
    end
  end
end
