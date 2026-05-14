if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.AutoScaling.Sandbox do
    @moduledoc false

    @registry :aws_auto_scaling_sandbox
    @state "state"
    @disabled "disabled"
    @sleep 10
    @keys :unique

    def start_link do
      Registry.start_link(keys: @keys, name: @registry)
    end

    # ---------------------------------------------------------------------------
    # Response retrieval
    # ---------------------------------------------------------------------------

    def describe_auto_scaling_groups_response(opts) do
      doc_examples = ["fn -> ... end", "fn opts -> ... end"]
      func = find!(:describe_auto_scaling_groups, "*", doc_examples)
      apply_func(func, [opts], doc_examples)
    end

    def describe_auto_scaling_instances_response(opts) do
      doc_examples = ["fn -> ... end", "fn opts -> ... end"]
      func = find!(:describe_auto_scaling_instances, "*", doc_examples)
      apply_func(func, [opts], doc_examples)
    end

    def describe_instance_refreshes_response(asg, opts) do
      doc_examples = ["fn -> ... end", "fn asg -> ... end", "fn asg, opts -> ... end"]
      func = find!(:describe_instance_refreshes, asg, doc_examples)
      apply_func(func, [asg, opts], doc_examples)
    end

    def start_instance_refresh_response(asg, opts) do
      doc_examples = ["fn -> ... end", "fn asg -> ... end", "fn asg, opts -> ... end"]
      func = find!(:start_instance_refresh, asg, doc_examples)
      apply_func(func, [asg, opts], doc_examples)
    end

    def cancel_instance_refresh_response(asg, opts) do
      doc_examples = ["fn -> ... end", "fn asg -> ... end", "fn asg, opts -> ... end"]
      func = find!(:cancel_instance_refresh, asg, doc_examples)
      apply_func(func, [asg, opts], doc_examples)
    end

    def rollback_instance_refresh_response(asg, opts) do
      doc_examples = ["fn -> ... end", "fn asg -> ... end", "fn asg, opts -> ... end"]
      func = find!(:rollback_instance_refresh, asg, doc_examples)
      apply_func(func, [asg, opts], doc_examples)
    end

    def complete_lifecycle_action_response(opts) do
      doc_examples = ["fn -> ... end", "fn opts -> ... end"]
      key = lifecycle_key(opts)
      func = find!(:complete_lifecycle_action, key, doc_examples)
      apply_func(func, [opts], doc_examples)
    end

    def record_lifecycle_action_heartbeat_response(opts) do
      doc_examples = ["fn -> ... end", "fn opts -> ... end"]
      key = lifecycle_key(opts)
      func = find!(:record_lifecycle_action_heartbeat, key, doc_examples)
      apply_func(func, [opts], doc_examples)
    end

    def set_instance_health_response(instance_id, health_status, opts) do
      doc_examples = [
        "fn -> ... end",
        "fn instance_id -> ... end",
        "fn instance_id, health_status, opts -> ... end"
      ]

      func = find!(:set_instance_health, instance_id, doc_examples)
      apply_func(func, [instance_id, health_status, opts], doc_examples)
    end

    def terminate_instance_in_auto_scaling_group_response(instance_id, should_decrement, opts) do
      doc_examples = [
        "fn -> ... end",
        "fn instance_id -> ... end",
        "fn instance_id, should_decrement, opts -> ... end"
      ]

      func = find!(:terminate_instance_in_auto_scaling_group, instance_id, doc_examples)
      apply_func(func, [instance_id, should_decrement, opts], doc_examples)
    end

    def set_desired_capacity_response(asg, desired_capacity, opts) do
      doc_examples = [
        "fn -> ... end",
        "fn asg -> ... end",
        "fn asg, desired_capacity, opts -> ... end"
      ]

      func = find!(:set_desired_capacity, asg, doc_examples)
      apply_func(func, [asg, desired_capacity, opts], doc_examples)
    end

    # ---------------------------------------------------------------------------
    # Response registration
    # ---------------------------------------------------------------------------

    def set_describe_auto_scaling_groups_responses(tuples_or_funcs),
      do: set_responses(:describe_auto_scaling_groups, normalize_no_key(tuples_or_funcs))

    def set_describe_auto_scaling_instances_responses(tuples_or_funcs),
      do: set_responses(:describe_auto_scaling_instances, normalize_no_key(tuples_or_funcs))

    def set_describe_instance_refreshes_responses(tuples),
      do: set_responses(:describe_instance_refreshes, tuples)

    def set_start_instance_refresh_responses(tuples),
      do: set_responses(:start_instance_refresh, tuples)

    def set_cancel_instance_refresh_responses(tuples),
      do: set_responses(:cancel_instance_refresh, tuples)

    def set_rollback_instance_refresh_responses(tuples),
      do: set_responses(:rollback_instance_refresh, tuples)

    def set_complete_lifecycle_action_responses(tuples),
      do: set_responses(:complete_lifecycle_action, tuples)

    def set_record_lifecycle_action_heartbeat_responses(tuples),
      do: set_responses(:record_lifecycle_action_heartbeat, tuples)

    def set_set_instance_health_responses(tuples),
      do: set_responses(:set_instance_health, tuples)

    def set_terminate_instance_in_auto_scaling_group_responses(tuples),
      do: set_responses(:terminate_instance_in_auto_scaling_group, tuples)

    def set_set_desired_capacity_responses(tuples),
      do: set_responses(:set_desired_capacity, tuples)

    # ---------------------------------------------------------------------------
    # Sandbox control
    # ---------------------------------------------------------------------------

    @spec disable_auto_scaling_sandbox(map) :: :ok
    def disable_auto_scaling_sandbox(_context) do
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

    # ---------------------------------------------------------------------------
    # Private helpers
    # ---------------------------------------------------------------------------

    defp lifecycle_key(opts) do
      hook = opts[:lifecycle_hook_name] || ""
      asg = opts[:auto_scaling_group_name] || ""
      "#{hook}|#{asg}"
    end

    defp normalize_no_key(items) do
      Enum.map(items, fn
        {_key, _func} = tuple -> tuple
        func when is_function(func) -> {"*", func}
      end)
    end

    defp set_responses(action, tuples) do
      tuples
      |> Map.new(fn {name, func} -> {{action, name}, func} end)
      |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
      |> then(fn
        :ok -> :ok
        {:error, :registry_not_started} -> raise_not_started!()
      end)

      Process.sleep(@sleep)
    end

    defp apply_func(func, args, doc_examples) do
      arity = :erlang.fun_info(func)[:arity]
      max_arity = length(args)

      cond do
        arity === 0 ->
          func.()

        arity <= max_arity ->
          apply(func, Enum.take(args, arity))

        true ->
          raise_unsupported_arity(func, doc_examples)
      end
    end

    defp find!(action, name, doc_examples) do
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
          raise_not_started!()
      end
    end

    defp find_response!(state, action, name, doc_examples) do
      sandbox_key = {action, name}

      with state when is_map(state) <- Map.get(state, sandbox_key, state),
           regexes <-
             Enum.filter(state, fn {{_a, p}, _f} -> regex?(p) end),
           {_pattern, func} when is_function(func) <-
             Enum.find(regexes, state, fn {{registered_action, regex}, _func} ->
               registered_action === action and Regex.match?(regex, name)
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
        #{Enum.map_join(doc_examples, "\n  # or\n", &("  " <> &1))}
          # or
          {~r|pattern|, fn -> _response end}
        ])
      end
      """
    end

    defp raise_unsupported_arity(func, doc_examples) do
      raise """
      Unsupported arity for sandbox response function #{inspect(func)}.

      Use one of:

      #{Enum.map_join(doc_examples, "\n", &"  #{&1}")}
      """
    end

    defp raise_not_started! do
      raise """
      Registry not started for #{inspect(__MODULE__)}.

      Add the following line to your `test_helper.exs`:

          #{inspect(__MODULE__)}.start_link()
      """
    end
  end
end
