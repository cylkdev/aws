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

  describe "describe_target_health/2" do
    test "returns the response registered under the exact target group arn" do
      Sandbox.set_describe_target_health_responses([
        {"arn:tg/mine",
         fn ->
           {:ok,
            %{
              target_health_descriptions: [
                %{target_id: "i-0abc", port: 4000, state: "healthy"}
              ]
            }}
         end}
      ])

      assert {:ok, %{target_health_descriptions: [%{target_id: "i-0abc", state: "healthy"}]}} =
               ElasticLoadBalancingV2.describe_target_health("arn:tg/mine", @sandbox_opts)
    end

    test "matches a regex key and passes the arn to a 1-arity function" do
      Sandbox.set_describe_target_health_responses([
        {~r|targetgroup/web|,
         fn arn ->
           {:ok, %{target_health_descriptions: [%{target_id: arn, port: 0, state: "echo"}]}}
         end}
      ])

      assert {:ok, %{target_health_descriptions: [%{target_id: "arn:targetgroup/web-dev"}]}} =
               ElasticLoadBalancingV2.describe_target_health(
                 "arn:targetgroup/web-dev",
                 @sandbox_opts
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

  describe "describe_listeners/2" do
    test "returns the response registered under the load balancer arn" do
      Sandbox.set_describe_listeners_responses([
        {"arn:lb/x",
         fn ->
           {:ok, %{listeners: [%{listener_arn: "arn:listener/80", port: 80}], next_token: nil}}
         end}
      ])

      assert {:ok, %{listeners: [%{port: 80}]}} =
               ElasticLoadBalancingV2.describe_listeners("arn:lb/x", @sandbox_opts)
    end

    test "2-arity function receives the arn and the call opts" do
      Sandbox.set_describe_listeners_responses([
        {"arn:lb/x",
         fn arn, opts -> {:ok, %{listeners: [], next_token: {arn, opts[:page_size]}}} end}
      ])

      assert {:ok, %{next_token: {"arn:lb/x", 10}}} =
               ElasticLoadBalancingV2.describe_listeners(
                 "arn:lb/x",
                 Keyword.put(@sandbox_opts, :page_size, 10)
               )
    end

    test "requires a binary load balancer arn" do
      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.describe_listeners(nil, @sandbox_opts)
      end
    end
  end

  describe "describe_listeners_by_arns/2" do
    test "keys off the joined listener arns and passes the list through" do
      Sandbox.set_describe_listeners_by_arns_responses([
        {"arn:listener/80,arn:listener/443",
         fn arns -> {:ok, %{listeners: [], next_token: arns}} end}
      ])

      assert {:ok, %{next_token: ["arn:listener/80", "arn:listener/443"]}} =
               ElasticLoadBalancingV2.describe_listeners_by_arns(
                 ["arn:listener/80", "arn:listener/443"],
                 @sandbox_opts
               )
    end

    test "requires a non-empty list" do
      # Built at runtime so the type checker does not reject the literal [].
      empty = List.delete(["arn:listener/80"], "arn:listener/80")

      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.describe_listeners_by_arns(empty, @sandbox_opts)
      end
    end
  end

  describe "describe_rules/2" do
    test "returns the response registered under the listener arn" do
      Sandbox.set_describe_rules_responses([
        {"arn:listener/80",
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
         end}
      ])

      assert {:ok, %{rules: [%{rule_arn: "arn:rule/1"}]}} =
               ElasticLoadBalancingV2.describe_rules("arn:listener/80", @sandbox_opts)
    end

    test "1-arity function receives the listener arn" do
      Sandbox.set_describe_rules_responses([
        {~r|listener|, fn arn -> {:ok, %{rules: [], next_token: arn}} end}
      ])

      assert {:ok, %{next_token: "arn:listener/80"}} =
               ElasticLoadBalancingV2.describe_rules("arn:listener/80", @sandbox_opts)
    end

    test "requires a binary listener arn" do
      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.describe_rules(nil, @sandbox_opts)
      end
    end
  end

  describe "describe_rules_by_arns/2" do
    test "keys off the joined rule arns and passes the list through" do
      Sandbox.set_describe_rules_by_arns_responses([
        {"arn:rule/1,arn:rule/2", fn arns -> {:ok, %{rules: [], next_token: arns}} end}
      ])

      assert {:ok, %{next_token: ["arn:rule/1", "arn:rule/2"]}} =
               ElasticLoadBalancingV2.describe_rules_by_arns(
                 ["arn:rule/1", "arn:rule/2"],
                 @sandbox_opts
               )
    end

    test "requires a non-empty list" do
      # Built at runtime so the type checker does not reject the literal [].
      empty = List.delete(["arn:rule/1"], "arn:rule/1")

      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.describe_rules_by_arns(empty, @sandbox_opts)
      end
    end
  end

  describe "modify_rule/3" do
    test "returns the response registered under the rule arn" do
      Sandbox.set_modify_rule_responses([
        {"arn:rule/1", fn -> {:ok, %{rules: [%{rule_arn: "arn:rule/1"}]}} end}
      ])

      assert {:ok, %{rules: [%{rule_arn: "arn:rule/1"}]}} =
               ElasticLoadBalancingV2.modify_rule(
                 "arn:rule/1",
                 [%{"Type" => "forward"}],
                 @sandbox_opts
               )
    end

    test "3-arity function receives the arn, the actions, and the call opts" do
      Sandbox.set_modify_rule_responses([
        {"arn:rule/1",
         fn arn, actions, opts -> {:ok, %{seen: {arn, actions, opts[:conditions]}}} end}
      ])

      assert {:ok, %{seen: {"arn:rule/1", [%{"Type" => "forward"}], [%{"Field" => "path"}]}}} =
               ElasticLoadBalancingV2.modify_rule(
                 "arn:rule/1",
                 [%{"Type" => "forward"}],
                 Keyword.put(@sandbox_opts, :conditions, [%{"Field" => "path"}])
               )
    end

    test "requires a binary rule arn and a list of actions" do
      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.modify_rule(nil, [], @sandbox_opts)
      end

      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.modify_rule("arn:rule/1", nil, @sandbox_opts)
      end
    end
  end
end
