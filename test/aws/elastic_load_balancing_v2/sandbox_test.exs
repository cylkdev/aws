defmodule AWS.ElasticLoadBalancingV2.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.ElasticLoadBalancingV2
  alias AWS.ElasticLoadBalancingV2.Sandbox

  @sandbox_opts [sandbox: [enabled: true]]

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

  describe "describe_load_balancers/1" do
    test "returns a registered list" do
      Sandbox.set_describe_load_balancers_responses([
        fn ->
          {:ok,
           %{
             load_balancers: [
               %{load_balancer_arn: "arn:lb/deployd-dev", load_balancer_name: "deployd-dev"}
             ],
             next_token: nil
           }}
        end
      ])

      assert {:ok, %{load_balancers: [%{load_balancer_name: "deployd-dev"}]}} =
               ElasticLoadBalancingV2.describe_load_balancers(
                 Keyword.put(@sandbox_opts, :names, ["deployd-dev"])
               )
    end

    test "1-arity function receives the call opts" do
      Sandbox.set_describe_load_balancers_responses([
        fn opts -> {:ok, %{load_balancers: [], next_token: opts[:names]}} end
      ])

      assert {:ok, %{next_token: ["deployd-dev"]}} =
               ElasticLoadBalancingV2.describe_load_balancers(
                 Keyword.put(@sandbox_opts, :names, ["deployd-dev"])
               )
    end
  end

  describe "describe_listeners/1" do
    test "returns a registered list" do
      Sandbox.set_describe_listeners_responses([
        fn ->
          {:ok, %{listeners: [%{listener_arn: "arn:listener/80", port: 80}], next_token: nil}}
        end
      ])

      assert {:ok, %{listeners: [%{port: 80}]}} =
               ElasticLoadBalancingV2.describe_listeners(
                 Keyword.put(@sandbox_opts, :load_balancer_arn, "arn:lb/x")
               )
    end

    test "1-arity function receives the call opts" do
      Sandbox.set_describe_listeners_responses([
        fn opts -> {:ok, %{listeners: [], next_token: opts[:load_balancer_arn]}} end
      ])

      assert {:ok, %{next_token: "arn:lb/x"}} =
               ElasticLoadBalancingV2.describe_listeners(
                 Keyword.put(@sandbox_opts, :load_balancer_arn, "arn:lb/x")
               )
    end

    test "requires a load balancer arn or listener arns" do
      assert_raise ArgumentError, ~r/:load_balancer_arn/, fn ->
        ElasticLoadBalancingV2.describe_listeners(@sandbox_opts)
      end
    end
  end

  describe "describe_rules/1" do
    test "returns a registered list" do
      Sandbox.set_describe_rules_responses([
        fn ->
          {:ok,
           %{
             rules: [
               %{
                 rule_arn: "arn:rule/1",
                 conditions: [%{field: "host-header", host_header_values: ["web.internal"]}],
                 actions: [
                   %{
                     type: "forward",
                     target_groups: [%{target_group_arn: "arn:tg/green", weight: 100}]
                   }
                 ]
               }
             ],
             next_token: nil
           }}
        end
      ])

      assert {:ok, %{rules: [%{rule_arn: "arn:rule/1"}]}} =
               ElasticLoadBalancingV2.describe_rules(
                 Keyword.put(@sandbox_opts, :listener_arn, "arn:listener/80")
               )
    end

    test "1-arity function receives the call opts" do
      Sandbox.set_describe_rules_responses([
        fn opts -> {:ok, %{rules: [], next_token: opts[:listener_arn]}} end
      ])

      assert {:ok, %{next_token: "arn:listener/80"}} =
               ElasticLoadBalancingV2.describe_rules(
                 Keyword.put(@sandbox_opts, :listener_arn, "arn:listener/80")
               )
    end

    test "requires a listener arn or rule arns" do
      assert_raise ArgumentError, ~r/:listener_arn/, fn ->
        ElasticLoadBalancingV2.describe_rules(@sandbox_opts)
      end
    end
  end

  describe "modify_rule/1" do
    test "returns a registered response" do
      Sandbox.set_modify_rule_responses([
        fn -> {:ok, %{rules: [%{rule_arn: "arn:rule/1"}]}} end
      ])

      assert {:ok, %{rules: [%{rule_arn: "arn:rule/1"}]}} =
               ElasticLoadBalancingV2.modify_rule(
                 @sandbox_opts ++
                   [rule_arn: "arn:rule/1", actions: [%{"Type" => "forward"}]]
               )
    end

    test "1-arity function receives the call opts" do
      Sandbox.set_modify_rule_responses([
        fn opts -> {:ok, %{rules: opts[:actions]}} end
      ])

      assert {:ok, %{rules: [%{"Type" => "forward"}]}} =
               ElasticLoadBalancingV2.modify_rule(
                 @sandbox_opts ++
                   [rule_arn: "arn:rule/1", actions: [%{"Type" => "forward"}]]
               )
    end

    test "requires a rule arn" do
      assert_raise ArgumentError, ~r/:rule_arn/, fn ->
        ElasticLoadBalancingV2.modify_rule(@sandbox_opts)
      end
    end
  end
end
