if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.EventBridge.Sandbox do
    use AWS.Sandbox,
      registry: :aws_event_bridge_sandbox,
      operations: [
        put_rule: [:name],
        describe_rule: [:name],
        list_rules: [],
        delete_rule: [:name],
        put_targets: [:rule, :targets],
        list_targets_by_rule: [:rule],
        remove_targets: [:rule, :ids],
        create_connection: [:name, :authorization_type, :auth_parameters],
        describe_connection: [:name],
        update_connection: [:name],
        delete_connection: [:name],
        list_connections: [],
        create_api_destination: [
          :name,
          :connection_arn,
          :invocation_endpoint,
          :http_method
        ],
        describe_api_destination: [:name],
        update_api_destination: [:name],
        delete_api_destination: [:name],
        list_api_destinations: [],
        create_event_bus: [:name],
        describe_event_bus: [:name],
        delete_event_bus: [:name],
        list_event_buses: [],
        put_events: {[:entries], fn _ -> "*" end},
        enable_rule: [:name],
        disable_rule: [:name]
      ]
  end
end
