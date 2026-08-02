if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.AutoScaling.Sandbox do
    use AWS.Sandbox,
      registry: :aws_auto_scaling_sandbox,
      operations: [
        describe_auto_scaling_groups: [],
        describe_auto_scaling_instances: [],
        describe_instance_refreshes: [:asg],
        start_instance_refresh: [:asg],
        cancel_instance_refresh: [:asg],
        rollback_instance_refresh: [:asg],
        complete_lifecycle_action:
          {[:hook, :asg, :result], fn [hook, asg, _result] -> "#{hook}|#{asg}" end},
        record_lifecycle_action_heartbeat:
          {[:hook, :asg], fn [hook, asg] -> "#{hook}|#{asg}" end},
        set_instance_health: [:instance_id, :health_status],
        terminate_instance_in_auto_scaling_group: [:instance_id, :should_decrement],
        set_desired_capacity: [:asg, :desired_capacity]
      ]
  end
end
