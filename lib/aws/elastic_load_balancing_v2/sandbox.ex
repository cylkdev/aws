if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.ElasticLoadBalancingV2.Sandbox do
    @moduledoc false

    @registry :aws_elastic_load_balancing_v2_sandbox
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

    def describe_target_groups_response(opts) do
      doc_examples = ["fn -> ... end", "fn opts -> ... end"]
      func = find!(:describe_target_groups, "*", doc_examples)
      apply_func(func, [opts], doc_examples)
    end

    def describe_target_health_response(target_group_arn, opts) do
      doc_examples = [
        "fn -> ... end",
        "fn target_group_arn -> ... end",
        "fn target_group_arn, opts -> ... end"
      ]

      func = find!(:describe_target_health, target_group_arn, doc_examples)
      apply_func(func, [target_group_arn, opts], doc_examples)
    end

    def describe_load_balancers_response(opts) do
      doc_examples = ["fn -> ... end", "fn opts -> ... end"]
      func = find!(:describe_load_balancers, "*", doc_examples)
      apply_func(func, [opts], doc_examples)
    end

    def describe_listeners_response(load_balancer_arn, opts) do
      doc_examples = [
        "fn -> ... end",
        "fn load_balancer_arn -> ... end",
        "fn load_balancer_arn, opts -> ... end"
      ]

      func = find!(:describe_listeners, load_balancer_arn, doc_examples)
      apply_func(func, [load_balancer_arn, opts], doc_examples)
    end

    def describe_listeners_by_arns_response(listener_arns, opts) do
      doc_examples = [
        "fn -> ... end",
        "fn listener_arns -> ... end",
        "fn listener_arns, opts -> ... end"
      ]

      func = find!(:describe_listeners_by_arns, arns_key(listener_arns), doc_examples)
      apply_func(func, [listener_arns, opts], doc_examples)
    end

    def describe_rules_response(listener_arn, opts) do
      doc_examples = [
        "fn -> ... end",
        "fn listener_arn -> ... end",
        "fn listener_arn, opts -> ... end"
      ]

      func = find!(:describe_rules, listener_arn, doc_examples)
      apply_func(func, [listener_arn, opts], doc_examples)
    end

    def describe_rules_by_arns_response(rule_arns, opts) do
      doc_examples = [
        "fn -> ... end",
        "fn rule_arns -> ... end",
        "fn rule_arns, opts -> ... end"
      ]

      func = find!(:describe_rules_by_arns, arns_key(rule_arns), doc_examples)
      apply_func(func, [rule_arns, opts], doc_examples)
    end

    def modify_rule_response(rule_arn, actions, opts) do
      doc_examples = [
        "fn -> ... end",
        "fn rule_arn -> ... end",
        "fn rule_arn, actions, opts -> ... end"
      ]

      func = find!(:modify_rule, rule_arn, doc_examples)
      apply_func(func, [rule_arn, actions, opts], doc_examples)
    end

    # ---------------------------------------------------------------------------
    # Response registration
    # ---------------------------------------------------------------------------

    def set_describe_target_groups_responses(tuples_or_funcs),
      do: set_responses(:describe_target_groups, normalize_no_key(tuples_or_funcs))

    def set_describe_target_health_responses(tuples),
      do: set_responses(:describe_target_health, tuples)

    def set_describe_load_balancers_responses(tuples_or_funcs),
      do: set_responses(:describe_load_balancers, normalize_no_key(tuples_or_funcs))

    def set_describe_listeners_responses(tuples),
      do: set_responses(:describe_listeners, tuples)

    def set_describe_listeners_by_arns_responses(tuples),
      do: set_responses(:describe_listeners_by_arns, tuples)

    def set_describe_rules_responses(tuples),
      do: set_responses(:describe_rules, tuples)

    def set_describe_rules_by_arns_responses(tuples),
      do: set_responses(:describe_rules_by_arns, tuples)

    def set_modify_rule_responses(tuples),
      do: set_responses(:modify_rule, tuples)

    # ---------------------------------------------------------------------------
    # Sandbox control
    # ---------------------------------------------------------------------------

    @spec disable_elastic_load_balancing_v2_sandbox(map) :: :ok
    def disable_elastic_load_balancing_v2_sandbox(_context) do
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

    # A list of ARNs has no single natural lookup key; join it so tests can
    # register an exact string or match it with a regex.
    defp arns_key(arns) when is_list(arns), do: Enum.join(arns, ",")

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
