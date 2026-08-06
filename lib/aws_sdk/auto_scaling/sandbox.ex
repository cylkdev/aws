if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.AutoScaling.Sandbox do
    @moduledoc false

    @registry :aws_auto_scaling_sandbox

    def start_link, do: AwsSdk.Sandbox.start_link(@registry)

    @spec disable_aws_auto_scaling_sandbox(map) :: :ok
    def disable_aws_auto_scaling_sandbox(_context),
      do: AwsSdk.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AwsSdk.Sandbox.disabled?(@registry, __MODULE__)

    def describe_auto_scaling_groups_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_auto_scaling_groups, "*", examples)

      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_auto_scaling_groups_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_auto_scaling_groups,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_auto_scaling_instances_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_auto_scaling_instances,
          "*",
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_auto_scaling_instances_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_auto_scaling_instances,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_instance_refreshes_response(asg, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:asg])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_instance_refreshes, asg, examples)

      AwsSdk.Sandbox.apply_func(func, [asg, opts], examples)
    end

    def set_describe_instance_refreshes_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_instance_refreshes,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_scaling_activities_response(asg, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:asg])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_scaling_activities, asg, examples)

      AwsSdk.Sandbox.apply_func(func, [asg, opts], examples)
    end

    def set_describe_scaling_activities_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_scaling_activities,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def start_instance_refresh_response(asg, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:asg])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :start_instance_refresh, asg, examples)
      AwsSdk.Sandbox.apply_func(func, [asg, opts], examples)
    end

    def set_start_instance_refresh_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :start_instance_refresh,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def cancel_instance_refresh_response(asg, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:asg])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :cancel_instance_refresh, asg, examples)
      AwsSdk.Sandbox.apply_func(func, [asg, opts], examples)
    end

    def set_cancel_instance_refresh_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :cancel_instance_refresh,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def rollback_instance_refresh_response(asg, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:asg])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :rollback_instance_refresh, asg, examples)

      AwsSdk.Sandbox.apply_func(func, [asg, opts], examples)
    end

    def set_rollback_instance_refresh_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :rollback_instance_refresh,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def complete_lifecycle_action_response(hook, asg, result, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:hook, :asg, :result])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :complete_lifecycle_action,
          "#{hook}|#{asg}",
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [hook, asg, result, opts], examples)
    end

    def set_complete_lifecycle_action_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :complete_lifecycle_action,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def record_lifecycle_action_heartbeat_response(hook, asg, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:hook, :asg])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :record_lifecycle_action_heartbeat,
          "#{hook}|#{asg}",
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [hook, asg, opts], examples)
    end

    def set_record_lifecycle_action_heartbeat_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :record_lifecycle_action_heartbeat,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def set_instance_health_response(instance_id, health_status, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_id, :health_status])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :set_instance_health, instance_id, examples)

      AwsSdk.Sandbox.apply_func(func, [instance_id, health_status, opts], examples)
    end

    def set_set_instance_health_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :set_instance_health,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def terminate_instance_in_auto_scaling_group_response(instance_id, should_decrement, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_id, :should_decrement])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :terminate_instance_in_auto_scaling_group,
          instance_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [instance_id, should_decrement, opts], examples)
    end

    def set_terminate_instance_in_auto_scaling_group_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :terminate_instance_in_auto_scaling_group,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def set_desired_capacity_response(asg, desired_capacity, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:asg, :desired_capacity])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :set_desired_capacity, asg, examples)
      AwsSdk.Sandbox.apply_func(func, [asg, desired_capacity, opts], examples)
    end

    def set_set_desired_capacity_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :set_desired_capacity,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
