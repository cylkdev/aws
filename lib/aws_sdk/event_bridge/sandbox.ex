if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.EventBridge.Sandbox do
    @moduledoc false

    @registry :aws_event_bridge_sandbox

    def start_link, do: AwsSdk.Sandbox.start_link(@registry)

    @spec disable_aws_event_bridge_sandbox(map) :: :ok
    def disable_aws_event_bridge_sandbox(_context),
      do: AwsSdk.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AwsSdk.Sandbox.disabled?(@registry, __MODULE__)

    def put_rule_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :put_rule, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_put_rule_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_rule,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_rule_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_rule, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_describe_rule_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_rule,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_rules_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_rules, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_rules_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_rules,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_rule_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_rule, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_rule_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_rule,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_targets_response(rule, targets, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:rule, :targets])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :put_targets, rule, examples)
      AwsSdk.Sandbox.apply_func(func, [rule, targets, opts], examples)
    end

    def set_put_targets_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_targets,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_targets_by_rule_response(rule, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:rule])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_targets_by_rule, rule, examples)
      AwsSdk.Sandbox.apply_func(func, [rule, opts], examples)
    end

    def set_list_targets_by_rule_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_targets_by_rule,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def remove_targets_response(rule, ids, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:rule, :ids])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :remove_targets, rule, examples)
      AwsSdk.Sandbox.apply_func(func, [rule, ids, opts], examples)
    end

    def set_remove_targets_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :remove_targets,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_connection_response(name, authorization_type, auth_parameters, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name, :authorization_type, :auth_parameters])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_connection, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, authorization_type, auth_parameters, opts], examples)
    end

    def set_create_connection_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_connection,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_connection_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_connection, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_describe_connection_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_connection,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def update_connection_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :update_connection, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_update_connection_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :update_connection,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_connection_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_connection, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_connection_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_connection,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_connections_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_connections, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_connections_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_connections,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_api_destination_response(
          name,
          connection_arn,
          invocation_endpoint,
          http_method,
          opts
        ) do
      examples =
        AwsSdk.Sandbox.doc_examples([:name, :connection_arn, :invocation_endpoint, :http_method])

      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_api_destination, name, examples)

      AwsSdk.Sandbox.apply_func(
        func,
        [name, connection_arn, invocation_endpoint, http_method, opts],
        examples
      )
    end

    def set_create_api_destination_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_api_destination,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_api_destination_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_api_destination, name, examples)

      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_describe_api_destination_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_api_destination,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def update_api_destination_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :update_api_destination, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_update_api_destination_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :update_api_destination,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_api_destination_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_api_destination, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_api_destination_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_api_destination,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_api_destinations_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_api_destinations, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_api_destinations_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_api_destinations,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_event_bus_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_event_bus, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_event_bus_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_event_bus,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_event_bus_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_event_bus, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_describe_event_bus_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_event_bus,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_event_bus_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_event_bus, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_event_bus_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_event_bus,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_event_buses_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_event_buses, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_event_buses_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_event_buses,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_events_response(entries, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:entries])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :put_events, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [entries, opts], examples)
    end

    def set_put_events_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_events,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def enable_rule_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :enable_rule, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_enable_rule_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :enable_rule,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def disable_rule_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :disable_rule, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_disable_rule_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :disable_rule,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
