if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.Sandbox do
    @moduledoc """
    Shared implementation behind every `AWS.<Service>.Sandbox` module.

        use AWS.Sandbox,
          registry: :aws_elastic_load_balancing_v2_sandbox,
          operations: [
            describe_target_groups: [],                  # keyed on "*"
            describe_target_health: [:target_group_arn], # keyed on arg 1
            modify_rule: [:rule_arn, :actions],          # extra args do not key
            # custom key; the fn receives all positional args as a list
            describe_rules_by_arns: {[:rule_arns], fn [arns] -> Enum.join(arns, ",") end}
          ]

    Each entry is `name: arg_names`, listing the operation's positional
    arguments (not the trailing `opts`). They set the generated arity, the
    lookup key, and the `fn` shapes shown in error messages.

    Responses are stored per test PID under an exact string or a `Regex`;
    exact matches win. A response function may take any arity from 0 up to
    the operation's arguments plus `opts`.
    """

    @state "state"
    @disabled "disabled"
    @sleep 10
    @keys :unique

    # -------------------------------------------------------------------------
    # Runtime — one copy, shared by every service
    # -------------------------------------------------------------------------

    @doc false
    def start_link(registry), do: Registry.start_link(keys: @keys, name: registry)

    @doc false
    def disable(registry, module) do
      with {:error, :registry_not_started} <-
             SandboxRegistry.register(registry, @disabled, %{}, @keys) do
        raise_not_started!(module)
      end
    end

    @doc false
    def disabled?(registry, module) do
      case SandboxRegistry.lookup(registry, @disabled) do
        {:ok, _} -> true
        {:error, :registry_not_started} -> raise_not_started!(module)
        {:error, :pid_not_registered} -> false
      end
    end

    @doc false
    def set_responses(registry, module, action, tuples) do
      :ok =
        tuples
        |> Map.new(fn {name, func} -> {{action, name}, func} end)
        |> then(&SandboxRegistry.register(registry, @state, &1, @keys))
        |> then(fn
          :ok -> :ok
          {:error, :registry_not_started} -> raise_not_started!(module)
        end)

      :ok = Process.sleep(@sleep)
    end

    @doc false
    def normalize_no_key(items) do
      Enum.map(items, fn
        {_key, _func} = tuple -> tuple
        func when is_function(func) -> {"*", func}
      end)
    end

    @doc false
    def find!(registry, module, action, name, doc_examples) do
      case SandboxRegistry.lookup(registry, @state) do
        {:ok, state} ->
          find_response!(state, module, action, name, doc_examples)

        {:error, :pid_not_registered} ->
          raise """
          No functions have been registered for #{inspect(self())}.

          Action: #{inspect(action)}
          Name: #{inspect(name)}

          Add one of the following patterns to your test setup:

          #{format_example(module, action, doc_examples)}

          Replace `_response` with the value you want the sandbox to return.
          """

        {:error, :registry_not_started} ->
          raise_not_started!(module)
      end
    end

    @doc false
    def apply_func(func, args, doc_examples) do
      arity = :erlang.fun_info(func)[:arity]

      cond do
        arity === 0 -> func.()
        arity <= length(args) -> apply(func, Enum.take(args, arity))
        true -> raise_unsupported_arity(func, doc_examples)
      end
    end

    defp find_response!(state, module, action, name, doc_examples) do
      sandbox_key = {action, name}

      with state when is_map(state) <- Map.get(state, sandbox_key, state),
           regexes <- Enum.filter(state, fn {{_action, pattern}, _func} -> regex?(pattern) end),
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
            module
            |> format_example(action, doc_examples)
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

          #{format_example(module, action, doc_examples)}
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

    defp format_example(module, action, doc_examples) do
      """
      alias #{inspect(module)}

      setup do
        #{inspect(module)}.set_#{action}_responses([
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

    defp raise_not_started!(module) do
      raise """
      Registry not started for #{inspect(module)}.

      To fix this, add the following line to your `test_helper.exs`:

          #{inspect(module)}.start_link()
      """
    end

    # -------------------------------------------------------------------------
    # Generation
    # -------------------------------------------------------------------------

    @doc false
    def doc_examples(arg_names) do
      full = Enum.map_join(arg_names ++ [:opts], ", ", &to_string/1)

      case arg_names do
        [] -> ["fn -> ... end", "fn opts -> ... end"]
        [first | _] -> ["fn -> ... end", "fn #{first} -> ... end", "fn #{full} -> ... end"]
      end
    end

    defmacro __using__(opts) do
      registry = Keyword.fetch!(opts, :registry)
      operations = Keyword.fetch!(opts, :operations)
      disable_name = Keyword.get(opts, :disable_name) || disable_name_for(registry)

      ops = Enum.map(operations, &build_operation/1)

      quote do
        @moduledoc false

        @registry unquote(registry)

        def start_link, do: AWS.Sandbox.start_link(@registry)

        @spec unquote(disable_name)(map) :: :ok
        def unquote(disable_name)(_context), do: AWS.Sandbox.disable(@registry, __MODULE__)

        @spec sandbox_disabled? :: boolean
        def sandbox_disabled?, do: AWS.Sandbox.disabled?(@registry, __MODULE__)

        unquote(ops)
      end
    end

    defp disable_name_for(registry) do
      registry
      |> Atom.to_string()
      |> String.replace_suffix("_sandbox", "")
      |> then(&:"disable_#{&1}_sandbox")
    end

    # `name: [:a, :b]` or `name: {[:a, :b], key_fun}`
    defp build_operation({name, {arg_names, key_fun}}), do: gen(name, arg_names, key_fun)
    defp build_operation({name, arg_names}) when is_list(arg_names), do: gen(name, arg_names, nil)

    defp gen(name, arg_names, key_fun) do
      vars = Enum.map(arg_names, &Macro.var(&1, __MODULE__))
      opts_var = Macro.var(:opts, __MODULE__)
      examples = doc_examples(arg_names)

      key =
        cond do
          key_fun -> quote(do: unquote(key_fun).(unquote(vars)))
          arg_names === [] -> "*"
          true -> hd(vars)
        end

      quote do
        def unquote(:"#{name}_response")(unquote_splicing(vars), unquote(opts_var)) do
          examples = unquote(examples)
          func = AWS.Sandbox.find!(@registry, __MODULE__, unquote(name), unquote(key), examples)
          AWS.Sandbox.apply_func(func, unquote(vars ++ [opts_var]), examples)
        end

        def unquote(:"set_#{name}_responses")(tuples) do
          AWS.Sandbox.set_responses(
            @registry,
            __MODULE__,
            unquote(name),
            AWS.Sandbox.normalize_no_key(tuples)
          )
        end
      end
    end
  end
end
