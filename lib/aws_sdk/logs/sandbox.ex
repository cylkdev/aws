if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.Logs.Sandbox do
    @moduledoc false

    @registry :aws_logs_sandbox

    def start_link, do: AwsSdk.Sandbox.start_link(@registry)

    @spec disable_aws_logs_sandbox(map) :: :ok
    def disable_aws_logs_sandbox(_context), do: AwsSdk.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AwsSdk.Sandbox.disabled?(@registry, __MODULE__)

    def create_log_group_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_log_group, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_log_group_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_log_group,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_log_group_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_log_group, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_log_group_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_log_group,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_log_groups_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_log_groups, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_log_groups_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_log_groups,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_retention_policy_response(name, days, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name, :days])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :put_retention_policy, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, days, opts], examples)
    end

    def set_put_retention_policy_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_retention_policy,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_retention_policy_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_retention_policy, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_retention_policy_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_retention_policy,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_log_stream_response(group, stream, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group, :stream])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_log_stream, group, examples)
      AwsSdk.Sandbox.apply_func(func, [group, stream, opts], examples)
    end

    def set_create_log_stream_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_log_stream,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_log_stream_response(group, stream, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group, :stream])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_log_stream, group, examples)
      AwsSdk.Sandbox.apply_func(func, [group, stream, opts], examples)
    end

    def set_delete_log_stream_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_log_stream,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_log_streams_response(group, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_log_streams, group, examples)
      AwsSdk.Sandbox.apply_func(func, [group, opts], examples)
    end

    def set_describe_log_streams_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_log_streams,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_log_events_response(group, stream, events, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group, :stream, :events])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :put_log_events, group, examples)
      AwsSdk.Sandbox.apply_func(func, [group, stream, events, opts], examples)
    end

    def set_put_log_events_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_log_events,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_log_events_response(group, stream, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group, :stream])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :get_log_events, group, examples)
      AwsSdk.Sandbox.apply_func(func, [group, stream, opts], examples)
    end

    def set_get_log_events_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_log_events,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def filter_log_events_response(group, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :filter_log_events, group, examples)
      AwsSdk.Sandbox.apply_func(func, [group, opts], examples)
    end

    def set_filter_log_events_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :filter_log_events,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def start_query_response(group, start_time, end_time, query, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group, :start_time, :end_time, :query])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :start_query, group, examples)
      AwsSdk.Sandbox.apply_func(func, [group, start_time, end_time, query, opts], examples)
    end

    def set_start_query_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :start_query,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def start_query_for_log_groups_response(groups, start_time, end_time, query, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:groups, :start_time, :end_time, :query])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :start_query_for_log_groups,
          Enum.join(groups, ","),
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [groups, start_time, end_time, query, opts], examples)
    end

    def set_start_query_for_log_groups_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :start_query_for_log_groups,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def start_query_by_identifiers_response(identifiers, start_time, end_time, query, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:identifiers, :start_time, :end_time, :query])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :start_query_by_identifiers,
          Enum.join(identifiers, ","),
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [identifiers, start_time, end_time, query, opts], examples)
    end

    def set_start_query_by_identifiers_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :start_query_by_identifiers,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_query_results_response(query_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:query_id])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :get_query_results, query_id, examples)
      AwsSdk.Sandbox.apply_func(func, [query_id, opts], examples)
    end

    def set_get_query_results_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_query_results,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def stop_query_response(query_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:query_id])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :stop_query, query_id, examples)
      AwsSdk.Sandbox.apply_func(func, [query_id, opts], examples)
    end

    def set_stop_query_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :stop_query,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
