if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.SSM.Sandbox do
    @moduledoc false

    @registry :aws_ssm_sandbox
    @state "state"
    @disabled "disabled"
    @sleep 10
    @keys :unique

    def start_link do
      Registry.start_link(keys: @keys, name: @registry)
    end

    # Response retrieval functions

    def get_parameter_response(name, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:get_parameter, name, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def get_parameters_response(names, opts) do
      doc_examples = ["fn -> ...", "fn (names) -> ...", "fn (names, opts) -> ..."]
      func = find!(:get_parameters, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(names)
        2 -> func.(names, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def get_parameters_by_path_response(path, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:get_parameters_by_path, path, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def put_parameter_response(name, value, opts) do
      doc_examples = ["fn -> ...", "fn (value) -> ...", "fn (value, opts) -> ..."]
      func = find!(:put_parameter, name, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(value)
        2 -> func.(value, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def delete_parameter_response(name, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:delete_parameter, name, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def delete_parameters_response(names, opts) do
      doc_examples = ["fn -> ...", "fn (names) -> ...", "fn (names, opts) -> ..."]
      func = find!(:delete_parameters, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(names)
        2 -> func.(names, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def describe_parameters_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_parameters, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def describe_instance_information_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_instance_information, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response registration functions

    def set_get_parameter_responses(tuples), do: set_responses(:get_parameter, tuples)

    def set_get_parameters_responses(funcs),
      do: set_responses(:get_parameters, Enum.map(funcs, fn f -> {"*", f} end))

    def set_get_parameters_by_path_responses(tuples),
      do: set_responses(:get_parameters_by_path, tuples)

    def set_put_parameter_responses(tuples), do: set_responses(:put_parameter, tuples)
    def set_delete_parameter_responses(tuples), do: set_responses(:delete_parameter, tuples)

    def set_delete_parameters_responses(funcs),
      do: set_responses(:delete_parameters, Enum.map(funcs, fn f -> {"*", f} end))

    def set_describe_parameters_responses(funcs),
      do: set_responses(:describe_parameters, Enum.map(funcs, fn f -> {"*", f} end))

    def set_describe_instance_information_responses(funcs),
      do: set_responses(:describe_instance_information, Enum.map(funcs, fn f -> {"*", f} end))

    # Sandbox control

    @spec disable_ssm_sandbox(map) :: :ok
    def disable_ssm_sandbox(_context) do
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
