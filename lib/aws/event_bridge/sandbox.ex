defmodule AWS.EventBridge.Sandbox do
  @moduledoc false

  @registry :aws_event_bridge_sandbox
  @state "state"
  @disabled "disabled"
  @sleep 10
  @keys :unique

  def start_link do
    Registry.start_link(keys: @keys, name: @registry)
  end

  # Response retrieval functions — Rule management

  def put_rule_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:put_rule, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def describe_rule_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:describe_rule, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_rules_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_rules, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_rule_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_rule, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # Response retrieval functions — Target management

  def put_targets_response(rule, targets, opts) do
    doc_examples = ["fn -> ...", "fn (targets) -> ...", "fn (targets, opts) -> ..."]
    func = find!(:put_targets, rule, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(targets)
      2 -> func.(targets, opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_targets_by_rule_response(rule, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_targets_by_rule, rule, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def remove_targets_response(rule, ids, opts) do
    doc_examples = ["fn -> ...", "fn (ids) -> ...", "fn (ids, opts) -> ..."]
    func = find!(:remove_targets, rule, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(ids)
      2 -> func.(ids, opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # Response retrieval functions — Connection management

  def create_connection_response(name, _authorization_type, _auth_parameters, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_connection, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def describe_connection_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:describe_connection, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def update_connection_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:update_connection, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_connection_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_connection, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_connections_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_connections, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # Response retrieval functions — API Destination management

  def create_api_destination_response(name, _connection_arn, _invocation_endpoint, _http_method, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_api_destination, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def describe_api_destination_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:describe_api_destination, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def update_api_destination_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:update_api_destination, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_api_destination_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_api_destination, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_api_destinations_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_api_destinations, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # Response retrieval functions — Event Bus management

  def create_event_bus_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_event_bus, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def describe_event_bus_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:describe_event_bus, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_event_bus_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_event_bus, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_event_buses_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_event_buses, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # Response retrieval functions — Events

  def put_events_response(entries, opts) do
    doc_examples = ["fn -> ...", "fn (entries) -> ...", "fn (entries, opts) -> ..."]
    func = find!(:put_events, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(entries)
      2 -> func.(entries, opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # Response retrieval functions — Rule control

  def enable_rule_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:enable_rule, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def disable_rule_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:disable_rule, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # Response registration functions

  def set_put_rule_responses(tuples), do: set_responses(:put_rule, tuples)
  def set_describe_rule_responses(tuples), do: set_responses(:describe_rule, tuples)
  def set_list_rules_responses(funcs), do: set_responses(:list_rules, Enum.map(funcs, fn f -> {"*", f} end))
  def set_delete_rule_responses(tuples), do: set_responses(:delete_rule, tuples)
  def set_put_targets_responses(tuples), do: set_responses(:put_targets, tuples)
  def set_list_targets_by_rule_responses(tuples), do: set_responses(:list_targets_by_rule, tuples)
  def set_remove_targets_responses(tuples), do: set_responses(:remove_targets, tuples)
  def set_create_connection_responses(tuples), do: set_responses(:create_connection, tuples)
  def set_describe_connection_responses(tuples), do: set_responses(:describe_connection, tuples)
  def set_update_connection_responses(tuples), do: set_responses(:update_connection, tuples)
  def set_delete_connection_responses(tuples), do: set_responses(:delete_connection, tuples)
  def set_list_connections_responses(funcs), do: set_responses(:list_connections, Enum.map(funcs, fn f -> {"*", f} end))
  def set_create_api_destination_responses(tuples), do: set_responses(:create_api_destination, tuples)
  def set_describe_api_destination_responses(tuples), do: set_responses(:describe_api_destination, tuples)
  def set_update_api_destination_responses(tuples), do: set_responses(:update_api_destination, tuples)
  def set_delete_api_destination_responses(tuples), do: set_responses(:delete_api_destination, tuples)
  def set_list_api_destinations_responses(funcs), do: set_responses(:list_api_destinations, Enum.map(funcs, fn f -> {"*", f} end))
  def set_create_event_bus_responses(tuples), do: set_responses(:create_event_bus, tuples)
  def set_describe_event_bus_responses(tuples), do: set_responses(:describe_event_bus, tuples)
  def set_delete_event_bus_responses(tuples), do: set_responses(:delete_event_bus, tuples)
  def set_list_event_buses_responses(funcs), do: set_responses(:list_event_buses, Enum.map(funcs, fn f -> {"*", f} end))
  def set_put_events_responses(funcs), do: set_responses(:put_events, Enum.map(funcs, fn f -> {"*", f} end))
  def set_enable_rule_responses(tuples), do: set_responses(:enable_rule, tuples)
  def set_disable_rule_responses(tuples), do: set_responses(:disable_rule, tuples)

  # Sandbox control

  @spec disable_event_bridge_sandbox(map) :: :ok
  def disable_event_bridge_sandbox(_context) do
    with {:error, :registry_not_started} <-
           SandboxRegistry.register(@registry, @disabled, %{}, @keys) do
      raise_not_started!()
    end
  end

  @spec sandbox_disabled? :: boolean
  def sandbox_disabled? do
    case SandboxRegistry.lookup(@registry, @disabled) do
      {:ok, _} -> true
      {:error, :registry_not_started} -> raise_not_started!()
      {:error, :pid_not_registered} -> false
    end
  end

  # Private helpers

  defp set_responses(key, tuples) do
    tuples
    |> Map.new(fn {name, func} -> {{key, name}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  def find!(action, name, doc_examples) do
    case SandboxRegistry.lookup(@registry, @state) do
      {:ok, state} ->
        find_response!(state, action, name, doc_examples)

      {:error, :pid_not_registered} ->
        raise """
        No functions have been registered for #{inspect(self())}.

        Action: #{inspect(action)}
        Name: #{inspect(name)}

        Add one of the following patterns to your test setup:

        #{format_example(action, name, doc_examples)}

        Replace `_response` with the value you want the sandbox to return.
        """

      {:error, :registry_not_started} ->
        raise """
        Registry not started for #{inspect(__MODULE__)}.

        Add the following line to your `test_helper.exs`:

            #{inspect(__MODULE__)}.start_link()
        """
    end
  end

  defp find_response!(state, action, name, doc_examples) do
    sandbox_key = {action, name}

    with state when is_map(state) <- Map.get(state, sandbox_key, state),
         regexes <-
           Enum.filter(state, fn {{_registered_action, registered_pattern}, _func} ->
             regex?(registered_pattern)
           end),
         {_action_pattern, func} when is_function(func) <-
           Enum.find(regexes, state, fn {{registered_action, regex}, _func} ->
             Regex.match?(regex, name) and registered_action === action
           end) do
      func
    else
      func when is_function(func) ->
        func

      functions when is_map(functions) ->
        functions_text =
          Enum.map_join(functions, "\n", fn {key, val} ->
            " #{inspect(key)} => #{inspect(val)}"
          end)

        example =
          action
          |> format_example(name, doc_examples)
          |> indent("  ")

        raise """
        Function not found.

          action: #{inspect(action)}
          name: #{inspect(name)}
          pid: #{inspect(self())}

        Found:

        #{functions_text}

        ---

        You need to register mock responses for `#{inspect(action)}` requests.

        #{example}
        """

      other ->
        raise """
        Unrecognized input for #{inspect(sandbox_key)} in #{inspect(self())}.

        Found value:

        #{inspect(other)}

        To fix this, update your test setup:

        #{format_example(action, name, doc_examples)}
        """
    end
  end

  defp regex?(%Regex{}), do: true
  defp regex?(_), do: false

  defp indent(text, prefix) do
    text
    |> String.split("\n", trim: false)
    |> Enum.map_join("\n", &"#{prefix}#{&1}")
  end

  defp format_example(action, _name, doc_examples) do
    """
    alias #{inspect(__MODULE__)}

    setup do
      #{inspect(__MODULE__)}.set_#{action}_responses([
        #{Enum.map_join(doc_examples, "\n    # or\n", &("    " <> &1))}
        # or
        {~r|pattern|, fn -> _response end}
      ])
    end
    """
  end

  defp raise_unsupported_arity(func, doc_examples) do
    raise """
    This function's signature is not supported: #{inspect(func)}

    Please provide a function with one of the following arities (0-#{length(doc_examples) - 1}):

    #{Enum.map_join(doc_examples, "\n", &("    " <> &1))}
    """
  end

  defp raise_not_started! do
    raise """
    Registry not started for #{inspect(__MODULE__)}.

    To fix this, add the following line to your `test_helper.exs`:

        #{inspect(__MODULE__)}.start_link()
    """
  end
end
