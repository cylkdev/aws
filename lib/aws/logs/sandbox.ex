if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.Logs.Sandbox do
    use AWS.Sandbox,
      registry: :aws_logs_sandbox,
      operations: [
        create_log_group: [:name],
        delete_log_group: [:name],
        describe_log_groups: [],
        put_retention_policy: [:name, :days],
        delete_retention_policy: [:name],
        create_log_stream: [:group, :stream],
        delete_log_stream: [:group, :stream],
        describe_log_streams: [:group],
        put_log_events: [:group, :stream, :events],
        get_log_events: [:group, :stream],
        filter_log_events: [:group],
        start_query: [:group, :start_time, :end_time, :query],
        start_query_for_log_groups:
          {[:groups, :start_time, :end_time, :query], fn [gs | _] -> Enum.join(gs, ",") end},
        start_query_by_identifiers:
          {[:identifiers, :start_time, :end_time, :query],
           fn [ids | _] -> Enum.join(ids, ",") end},
        get_query_results: [:query_id],
        stop_query: [:query_id]
      ]
  end
end
