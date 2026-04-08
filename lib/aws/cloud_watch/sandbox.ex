defmodule AWS.CloudWatch.Sandbox do
  @moduledoc false

  @registry :aws_cloudwatch_sandbox
  @state "state"
  @disabled "disabled"
  @sleep 10
  @keys :unique

  def start_link do
    Registry.start_link(keys: @keys, name: @registry)
  end

  # Response retrieval functions — Alarms

  def put_metric_alarm_response(alarm_name, _comparison_operator, _evaluation_periods, _metric_name, _namespace, _period, _threshold, _statistic, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:put_metric_alarm, alarm_name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def describe_alarms_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:describe_alarms, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def describe_alarms_for_metric_response(metric_name, _namespace, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:describe_alarms_for_metric, metric_name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def describe_alarm_history_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:describe_alarm_history, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_alarms_response(alarm_names, opts) do
    doc_examples = ["fn -> ...", "fn (alarm_names) -> ...", "fn (alarm_names, opts) -> ..."]
    func = find!(:delete_alarms, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(alarm_names)
      2 -> func.(alarm_names, opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def enable_alarm_actions_response(alarm_names, opts) do
    doc_examples = ["fn -> ...", "fn (alarm_names) -> ...", "fn (alarm_names, opts) -> ..."]
    func = find!(:enable_alarm_actions, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(alarm_names)
      2 -> func.(alarm_names, opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def disable_alarm_actions_response(alarm_names, opts) do
    doc_examples = ["fn -> ...", "fn (alarm_names) -> ...", "fn (alarm_names, opts) -> ..."]
    func = find!(:disable_alarm_actions, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(alarm_names)
      2 -> func.(alarm_names, opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # Response retrieval functions — Metrics

  def get_metric_statistics_response(namespace, _metric_name, _start_time, _end_time, _period, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:get_metric_statistics, namespace, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_metrics_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_metrics, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def put_metric_data_response(_metric_data, namespace, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:put_metric_data, namespace, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # Response retrieval functions — Dashboards

  def put_dashboard_response(dashboard_name, _dashboard_body, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:put_dashboard, dashboard_name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def get_dashboard_response(dashboard_name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:get_dashboard, dashboard_name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_dashboards_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_dashboards, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_dashboards_response(dashboard_names, opts) do
    doc_examples = ["fn -> ...", "fn (dashboard_names) -> ...", "fn (dashboard_names, opts) -> ..."]
    func = find!(:delete_dashboards, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(dashboard_names)
      2 -> func.(dashboard_names, opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # Response registration functions

  def set_put_metric_alarm_responses(tuples), do: set_responses(:put_metric_alarm, tuples)
  def set_describe_alarms_responses(funcs), do: set_responses(:describe_alarms, Enum.map(funcs, fn f -> {"*", f} end))
  def set_describe_alarms_for_metric_responses(tuples), do: set_responses(:describe_alarms_for_metric, tuples)
  def set_describe_alarm_history_responses(funcs), do: set_responses(:describe_alarm_history, Enum.map(funcs, fn f -> {"*", f} end))
  def set_delete_alarms_responses(funcs), do: set_responses(:delete_alarms, Enum.map(funcs, fn f -> {"*", f} end))
  def set_enable_alarm_actions_responses(funcs), do: set_responses(:enable_alarm_actions, Enum.map(funcs, fn f -> {"*", f} end))
  def set_disable_alarm_actions_responses(funcs), do: set_responses(:disable_alarm_actions, Enum.map(funcs, fn f -> {"*", f} end))
  def set_get_metric_statistics_responses(tuples), do: set_responses(:get_metric_statistics, tuples)
  def set_list_metrics_responses(funcs), do: set_responses(:list_metrics, Enum.map(funcs, fn f -> {"*", f} end))
  def set_put_metric_data_responses(tuples), do: set_responses(:put_metric_data, tuples)
  def set_put_dashboard_responses(tuples), do: set_responses(:put_dashboard, tuples)
  def set_get_dashboard_responses(tuples), do: set_responses(:get_dashboard, tuples)
  def set_list_dashboards_responses(funcs), do: set_responses(:list_dashboards, Enum.map(funcs, fn f -> {"*", f} end))
  def set_delete_dashboards_responses(funcs), do: set_responses(:delete_dashboards, Enum.map(funcs, fn f -> {"*", f} end))

  # Sandbox control

  @spec disable_cloudwatch_sandbox(map) :: :ok
  def disable_cloudwatch_sandbox(_context) do
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

        #{example}
        """

      other ->
        raise """
        Unrecognized input for #{inspect(sandbox_key)} in #{inspect(self())}.

        Found value:

        #{inspect(other)}

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
