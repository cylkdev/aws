if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.ElasticLoadBalancingV2.Sandbox do
    use AWS.Sandbox,
      registry: :aws_elastic_load_balancing_v2_sandbox,
      operations: [
        describe_target_groups: [],
        describe_target_groups_by_names: {[:names], fn [names] -> Enum.join(names, ",") end},
        describe_target_groups_by_arns: {[:arns], fn [arns] -> Enum.join(arns, ",") end},
        describe_target_groups_by_load_balancer: [:load_balancer_arn],
        describe_target_health: [:target_group_arn],
        describe_load_balancers: [],
        describe_listeners: [:load_balancer_arn],
        describe_listeners_by_arns: {[:listener_arns], fn [arns] -> Enum.join(arns, ",") end},
        describe_rules: [:listener_arn],
        describe_rules_by_arns: {[:rule_arns], fn [arns] -> Enum.join(arns, ",") end},
        modify_rule: [:rule_arn, :actions]
      ]
  end
end
