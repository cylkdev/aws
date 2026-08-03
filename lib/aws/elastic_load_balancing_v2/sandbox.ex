if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.ElasticLoadBalancingV2.Sandbox do
    @moduledoc false

    @registry :aws_elastic_load_balancing_v2_sandbox

    def start_link, do: AWS.Sandbox.start_link(@registry)

    @spec disable_aws_elastic_load_balancing_v2_sandbox(map) :: :ok
    def disable_aws_elastic_load_balancing_v2_sandbox(_context),
      do: AWS.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AWS.Sandbox.disabled?(@registry, __MODULE__)

    def describe_target_groups_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_target_groups, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_target_groups_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_target_groups,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_target_groups_by_names_response(names, opts) do
      examples = AWS.Sandbox.doc_examples([:names])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_target_groups_by_names,
          Enum.join(names, ","),
          examples
        )

      AWS.Sandbox.apply_func(func, [names, opts], examples)
    end

    def set_describe_target_groups_by_names_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_target_groups_by_names,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_target_groups_by_arns_response(arns, opts) do
      examples = AWS.Sandbox.doc_examples([:arns])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_target_groups_by_arns,
          Enum.join(arns, ","),
          examples
        )

      AWS.Sandbox.apply_func(func, [arns, opts], examples)
    end

    def set_describe_target_groups_by_arns_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_target_groups_by_arns,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_target_groups_by_load_balancer_response(load_balancer_arn, opts) do
      examples = AWS.Sandbox.doc_examples([:load_balancer_arn])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_target_groups_by_load_balancer,
          load_balancer_arn,
          examples
        )

      AWS.Sandbox.apply_func(func, [load_balancer_arn, opts], examples)
    end

    def set_describe_target_groups_by_load_balancer_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_target_groups_by_load_balancer,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_target_health_response(target_group_arn, opts) do
      examples = AWS.Sandbox.doc_examples([:target_group_arn])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_target_health,
          target_group_arn,
          examples
        )

      AWS.Sandbox.apply_func(func, [target_group_arn, opts], examples)
    end

    def set_describe_target_health_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_target_health,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_load_balancers_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_load_balancers, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_load_balancers_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_load_balancers,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_listeners_response(load_balancer_arn, opts) do
      examples = AWS.Sandbox.doc_examples([:load_balancer_arn])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :describe_listeners, load_balancer_arn, examples)

      AWS.Sandbox.apply_func(func, [load_balancer_arn, opts], examples)
    end

    def set_describe_listeners_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_listeners,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_listeners_by_arns_response(listener_arns, opts) do
      examples = AWS.Sandbox.doc_examples([:listener_arns])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_listeners_by_arns,
          Enum.join(listener_arns, ","),
          examples
        )

      AWS.Sandbox.apply_func(func, [listener_arns, opts], examples)
    end

    def set_describe_listeners_by_arns_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_listeners_by_arns,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_rules_response(listener_arn, opts) do
      examples = AWS.Sandbox.doc_examples([:listener_arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_rules, listener_arn, examples)
      AWS.Sandbox.apply_func(func, [listener_arn, opts], examples)
    end

    def set_describe_rules_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_rules,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_rules_by_arns_response(rule_arns, opts) do
      examples = AWS.Sandbox.doc_examples([:rule_arns])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_rules_by_arns,
          Enum.join(rule_arns, ","),
          examples
        )

      AWS.Sandbox.apply_func(func, [rule_arns, opts], examples)
    end

    def set_describe_rules_by_arns_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_rules_by_arns,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def modify_rule_response(rule_arn, actions, opts) do
      examples = AWS.Sandbox.doc_examples([:rule_arn, :actions])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :modify_rule, rule_arn, examples)
      AWS.Sandbox.apply_func(func, [rule_arn, actions, opts], examples)
    end

    def set_modify_rule_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :modify_rule,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
