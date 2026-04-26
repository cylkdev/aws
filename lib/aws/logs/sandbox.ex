if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.Logs.Sandbox do
    @moduledoc false

    @registry :aws_logs_sandbox
    @state "state"
    @disabled "disabled"
    @sleep 10
    @keys :unique

    def start_link do
      Registry.start_link(keys: @keys, name: @registry)
    end

    # Response retrieval functions — Log Groups

    def create_log_group_response(name, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:create_log_group, name, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def delete_log_group_response(name, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:delete_log_group, name, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def describe_log_groups_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_log_groups, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def put_retention_policy_response(name, days, opts) do
      doc_examples = ["fn -> ...", "fn (days) -> ...", "fn (days, opts) -> ..."]
      func = find!(:put_retention_policy, name, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(days)
        2 -> func.(days, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def delete_retention_policy_response(name, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:delete_retention_policy, name, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response retrieval functions — Log Streams

    def create_log_stream_response(group, stream, opts) do
      doc_examples = ["fn -> ...", "fn (stream) -> ...", "fn (stream, opts) -> ..."]
      func = find!(:create_log_stream, group, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(stream)
        2 -> func.(stream, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def delete_log_stream_response(group, stream, opts) do
      doc_examples = ["fn -> ...", "fn (stream) -> ...", "fn (stream, opts) -> ..."]
      func = find!(:delete_log_stream, group, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(stream)
        2 -> func.(stream, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def describe_log_streams_response(group, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_log_streams, group, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response retrieval functions — Log Events

    def put_log_events_response(group, stream, events, opts) do
      doc_examples = [
        "fn -> ...",
        "fn (events) -> ...",
        "fn (stream, events) -> ...",
        "fn (stream, events, opts) -> ..."
      ]

      func = find!(:put_log_events, group, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(events)
        2 -> func.(stream, events)
        3 -> func.(stream, events, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def get_log_events_response(group, stream, opts) do
      doc_examples = ["fn -> ...", "fn (stream) -> ...", "fn (stream, opts) -> ..."]
      func = find!(:get_log_events, group, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(stream)
        2 -> func.(stream, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def filter_log_events_response(group, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:filter_log_events, group, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response retrieval functions — Insights Queries

    def start_query_response(group, start_time, end_time, query, opts) do
      doc_examples = [
        "fn -> ...",
        "fn (query) -> ...",
        "fn (start_time, end_time, query) -> ...",
        "fn (start_time, end_time, query, opts) -> ..."
      ]

      func = find!(:start_query, group, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(query)
        3 -> func.(start_time, end_time, query)
        4 -> func.(start_time, end_time, query, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def get_query_results_response(query_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:get_query_results, query_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def stop_query_response(query_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:stop_query, query_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response registration functions

    def set_create_log_group_responses(tuples), do: set_responses(:create_log_group, tuples)
    def set_delete_log_group_responses(tuples), do: set_responses(:delete_log_group, tuples)

    def set_describe_log_groups_responses(funcs),
      do: set_responses(:describe_log_groups, Enum.map(funcs, fn f -> {"*", f} end))

    def set_put_retention_policy_responses(tuples),
      do: set_responses(:put_retention_policy, tuples)

    def set_delete_retention_policy_responses(tuples),
      do: set_responses(:delete_retention_policy, tuples)

    def set_create_log_stream_responses(tuples), do: set_responses(:create_log_stream, tuples)
    def set_delete_log_stream_responses(tuples), do: set_responses(:delete_log_stream, tuples)

    def set_describe_log_streams_responses(tuples),
      do: set_responses(:describe_log_streams, tuples)

    def set_put_log_events_responses(tuples), do: set_responses(:put_log_events, tuples)
    def set_get_log_events_responses(tuples), do: set_responses(:get_log_events, tuples)
    def set_filter_log_events_responses(tuples), do: set_responses(:filter_log_events, tuples)
    def set_start_query_responses(tuples), do: set_responses(:start_query, tuples)
    def set_get_query_results_responses(tuples), do: set_responses(:get_query_results, tuples)
    def set_stop_query_responses(tuples), do: set_responses(:stop_query, tuples)

    # Sandbox control

    @spec disable_logs_sandbox(map) :: :ok
    def disable_logs_sandbox(_context) do
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
end
