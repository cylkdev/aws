if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.Sandbox do
    @moduledoc """
    Shared runtime behind every `AWS.<Service>.Sandbox` module. Each service's
    sandbox writes its own functions and calls these helpers:

        def describe_target_health_response(target_group_arn, opts) do
          examples = AWS.Sandbox.doc_examples([:target_group_arn])
          func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_target_health, target_group_arn, examples)
          AWS.Sandbox.apply_func(func, [target_group_arn, opts], examples)
        end

        def set_describe_target_health_responses(tuples) do
          AWS.Sandbox.set_responses(
            @registry,
            __MODULE__,
            :describe_target_health,
            AWS.Sandbox.normalize_no_key(tuples)
          )
        end

    The lookup key is normally the operation's first positional argument;
    operations with no required input key off `"*"`, and a few compute a key
    from their arguments (e.g. joining a list of ARNs). `doc_examples/1` takes
    the operation's positional argument names (not the trailing `opts`) and
    produces the `fn` shapes shown in error messages.

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

    @doc false
    def doc_examples(arg_names) do
      full = Enum.map_join(arg_names ++ [:opts], ", ", &to_string/1)

      case arg_names do
        [] -> ["fn -> ... end", "fn opts -> ... end"]
        [first | _] -> ["fn -> ... end", "fn #{first} -> ... end", "fn #{full} -> ... end"]
      end
    end
  end
end
