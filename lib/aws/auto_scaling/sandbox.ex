if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.AutoScaling.Sandbox do
    @moduledoc false

    @registry :aws_auto_scaling_sandbox

    def start_link, do: AWS.Sandbox.start_link(@registry)

    @spec disable_aws_auto_scaling_sandbox(map) :: :ok
    def disable_aws_auto_scaling_sandbox(_context), do: AWS.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AWS.Sandbox.disabled?(@registry, __MODULE__)

    def describe_auto_scaling_groups_response(opts) do
      examples = AWS.Sandbox.doc_examples([])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :describe_auto_scaling_groups, "*", examples)

      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_auto_scaling_groups_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_auto_scaling_groups,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_auto_scaling_instances_response(opts) do
      examples = AWS.Sandbox.doc_examples([])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :describe_auto_scaling_instances, "*", examples)

      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_auto_scaling_instances_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_auto_scaling_instances,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_instance_refreshes_response(asg, opts) do
      examples = AWS.Sandbox.doc_examples([:asg])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_instance_refreshes, asg, examples)
      AWS.Sandbox.apply_func(func, [asg, opts], examples)
    end

    def set_describe_instance_refreshes_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_instance_refreshes,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def start_instance_refresh_response(asg, opts) do
      examples = AWS.Sandbox.doc_examples([:asg])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :start_instance_refresh, asg, examples)
      AWS.Sandbox.apply_func(func, [asg, opts], examples)
    end

    def set_start_instance_refresh_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :start_instance_refresh,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def cancel_instance_refresh_response(asg, opts) do
      examples = AWS.Sandbox.doc_examples([:asg])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :cancel_instance_refresh, asg, examples)
      AWS.Sandbox.apply_func(func, [asg, opts], examples)
    end

    def set_cancel_instance_refresh_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :cancel_instance_refresh,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def rollback_instance_refresh_response(asg, opts) do
      examples = AWS.Sandbox.doc_examples([:asg])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :rollback_instance_refresh, asg, examples)
      AWS.Sandbox.apply_func(func, [asg, opts], examples)
    end

    def set_rollback_instance_refresh_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :rollback_instance_refresh,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def complete_lifecycle_action_response(hook, asg, result, opts) do
      examples = AWS.Sandbox.doc_examples([:hook, :asg, :result])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :complete_lifecycle_action,
          "#{hook}|#{asg}",
          examples
        )

      AWS.Sandbox.apply_func(func, [hook, asg, result, opts], examples)
    end

    def set_complete_lifecycle_action_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :complete_lifecycle_action,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def record_lifecycle_action_heartbeat_response(hook, asg, opts) do
      examples = AWS.Sandbox.doc_examples([:hook, :asg])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :record_lifecycle_action_heartbeat,
          "#{hook}|#{asg}",
          examples
        )

      AWS.Sandbox.apply_func(func, [hook, asg, opts], examples)
    end

    def set_record_lifecycle_action_heartbeat_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :record_lifecycle_action_heartbeat,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def set_instance_health_response(instance_id, health_status, opts) do
      examples = AWS.Sandbox.doc_examples([:instance_id, :health_status])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :set_instance_health, instance_id, examples)
      AWS.Sandbox.apply_func(func, [instance_id, health_status, opts], examples)
    end

    def set_set_instance_health_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :set_instance_health,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def terminate_instance_in_auto_scaling_group_response(instance_id, should_decrement, opts) do
      examples = AWS.Sandbox.doc_examples([:instance_id, :should_decrement])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :terminate_instance_in_auto_scaling_group,
          instance_id,
          examples
        )

      AWS.Sandbox.apply_func(func, [instance_id, should_decrement, opts], examples)
    end

    def set_terminate_instance_in_auto_scaling_group_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :terminate_instance_in_auto_scaling_group,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def set_desired_capacity_response(asg, desired_capacity, opts) do
      examples = AWS.Sandbox.doc_examples([:asg, :desired_capacity])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :set_desired_capacity, asg, examples)
      AWS.Sandbox.apply_func(func, [asg, desired_capacity, opts], examples)
    end

    def set_set_desired_capacity_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :set_desired_capacity,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
