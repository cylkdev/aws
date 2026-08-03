if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.EventBridge.Sandbox do
    @moduledoc false

    @registry :aws_event_bridge_sandbox

    def start_link, do: AWS.Sandbox.start_link(@registry)

    @spec disable_aws_event_bridge_sandbox(map) :: :ok
    def disable_aws_event_bridge_sandbox(_context), do: AWS.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AWS.Sandbox.disabled?(@registry, __MODULE__)

    def put_rule_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :put_rule, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_put_rule_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_rule,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_rule_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_rule, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_describe_rule_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_rule,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_rules_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_rules, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_rules_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_rules,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_rule_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_rule, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_rule_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_rule,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_targets_response(rule, targets, opts) do
      examples = AWS.Sandbox.doc_examples([:rule, :targets])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :put_targets, rule, examples)
      AWS.Sandbox.apply_func(func, [rule, targets, opts], examples)
    end

    def set_put_targets_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_targets,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_targets_by_rule_response(rule, opts) do
      examples = AWS.Sandbox.doc_examples([:rule])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_targets_by_rule, rule, examples)
      AWS.Sandbox.apply_func(func, [rule, opts], examples)
    end

    def set_list_targets_by_rule_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_targets_by_rule,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def remove_targets_response(rule, ids, opts) do
      examples = AWS.Sandbox.doc_examples([:rule, :ids])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :remove_targets, rule, examples)
      AWS.Sandbox.apply_func(func, [rule, ids, opts], examples)
    end

    def set_remove_targets_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :remove_targets,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_connection_response(name, authorization_type, auth_parameters, opts) do
      examples = AWS.Sandbox.doc_examples([:name, :authorization_type, :auth_parameters])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_connection, name, examples)
      AWS.Sandbox.apply_func(func, [name, authorization_type, auth_parameters, opts], examples)
    end

    def set_create_connection_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_connection,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_connection_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_connection, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_describe_connection_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_connection,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def update_connection_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :update_connection, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_update_connection_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :update_connection,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_connection_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_connection, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_connection_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_connection,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_connections_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_connections, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_connections_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_connections,
        AWS.Sandbox.normalize_no_key(tuples)
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
        AWS.Sandbox.doc_examples([:name, :connection_arn, :invocation_endpoint, :http_method])

      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_api_destination, name, examples)

      AWS.Sandbox.apply_func(
        func,
        [name, connection_arn, invocation_endpoint, http_method, opts],
        examples
      )
    end

    def set_create_api_destination_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_api_destination,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_api_destination_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_api_destination, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_describe_api_destination_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_api_destination,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def update_api_destination_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :update_api_destination, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_update_api_destination_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :update_api_destination,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_api_destination_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_api_destination, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_api_destination_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_api_destination,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_api_destinations_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_api_destinations, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_api_destinations_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_api_destinations,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_event_bus_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_event_bus, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_event_bus_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_event_bus,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_event_bus_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_event_bus, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_describe_event_bus_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_event_bus,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_event_bus_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_event_bus, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_event_bus_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_event_bus,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_event_buses_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_event_buses, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_event_buses_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_event_buses,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_events_response(entries, opts) do
      examples = AWS.Sandbox.doc_examples([:entries])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :put_events, "*", examples)
      AWS.Sandbox.apply_func(func, [entries, opts], examples)
    end

    def set_put_events_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_events,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def enable_rule_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :enable_rule, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_enable_rule_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :enable_rule,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def disable_rule_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :disable_rule, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_disable_rule_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :disable_rule,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
