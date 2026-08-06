if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.ElasticLoadBalancingV2.Sandbox do
    @moduledoc false

    @registry :aws_elastic_load_balancing_v2_sandbox

    def start_link, do: AwsSdk.Sandbox.start_link(@registry)

    @spec disable_aws_elastic_load_balancing_v2_sandbox(map) :: :ok
    def disable_aws_elastic_load_balancing_v2_sandbox(_context),
      do: AwsSdk.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AwsSdk.Sandbox.disabled?(@registry, __MODULE__)

    def describe_target_groups_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_target_groups, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_target_groups_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_target_groups,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_target_groups_by_names_response(names, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:names])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_target_groups_by_names,
          Enum.join(names, ","),
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [names, opts], examples)
    end

    def set_describe_target_groups_by_names_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_target_groups_by_names,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_target_groups_by_arns_response(arns, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:arns])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_target_groups_by_arns,
          Enum.join(arns, ","),
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [arns, opts], examples)
    end

    def set_describe_target_groups_by_arns_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_target_groups_by_arns,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_target_groups_by_load_balancer_response(load_balancer_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:load_balancer_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_target_groups_by_load_balancer,
          load_balancer_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [load_balancer_arn, opts], examples)
    end

    def set_describe_target_groups_by_load_balancer_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_target_groups_by_load_balancer,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_target_health_response(target_group_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:target_group_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_target_health,
          target_group_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [target_group_arn, opts], examples)
    end

    def set_describe_target_health_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_target_health,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_load_balancers_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_load_balancers, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_load_balancers_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_load_balancers,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_listeners_response(load_balancer_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:load_balancer_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_listeners,
          load_balancer_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [load_balancer_arn, opts], examples)
    end

    def set_describe_listeners_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_listeners,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_listeners_by_arns_response(listener_arns, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:listener_arns])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_listeners_by_arns,
          Enum.join(listener_arns, ","),
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [listener_arns, opts], examples)
    end

    def set_describe_listeners_by_arns_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_listeners_by_arns,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_rules_response(listener_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:listener_arn])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_rules, listener_arn, examples)
      AwsSdk.Sandbox.apply_func(func, [listener_arn, opts], examples)
    end

    def set_describe_rules_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_rules,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_rules_by_arns_response(rule_arns, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:rule_arns])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_rules_by_arns,
          Enum.join(rule_arns, ","),
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [rule_arns, opts], examples)
    end

    def set_describe_rules_by_arns_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_rules_by_arns,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def modify_rule_response(rule_arn, actions, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:rule_arn, :actions])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :modify_rule, rule_arn, examples)
      AwsSdk.Sandbox.apply_func(func, [rule_arn, actions, opts], examples)
    end

    def modify_listener_response(listener_arn, default_actions, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:listener_arn, :default_actions])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :modify_listener, listener_arn, examples)
      AwsSdk.Sandbox.apply_func(func, [listener_arn, default_actions, opts], examples)
    end

    def set_modify_listener_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :modify_listener,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def set_modify_rule_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :modify_rule,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
