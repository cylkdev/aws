if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.EC2.Sandbox do
    @moduledoc false

    @registry :aws_ec2_sandbox
    @state "state"
    @disabled "disabled"
    @sleep 10
    @keys :unique

    def start_link do
      Registry.start_link(keys: @keys, name: @registry)
    end

    # ---------------------------------------------------------------------------
    # Response retrieval — Security Groups
    # ---------------------------------------------------------------------------

    def create_security_group_response(name, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:create_security_group, name, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def describe_security_groups_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_security_groups, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def delete_security_group_response(group_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:delete_security_group, group_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def authorize_security_group_ingress_response(group_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:authorize_security_group_ingress, group_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def revoke_security_group_ingress_response(group_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:revoke_security_group_ingress, group_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def authorize_security_group_egress_response(group_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:authorize_security_group_egress, group_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def revoke_security_group_egress_response(group_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:revoke_security_group_egress, group_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # ---------------------------------------------------------------------------
    # Response retrieval — VPCs / Subnets
    # ---------------------------------------------------------------------------

    def describe_vpcs_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_vpcs, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def describe_subnets_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_subnets, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # ---------------------------------------------------------------------------
    # Response retrieval — Tags
    # ---------------------------------------------------------------------------

    def create_tags_response(resource_ids, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      key = List.first(resource_ids) || "*"
      func = find!(:create_tags, key, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # ---------------------------------------------------------------------------
    # Response registration
    # ---------------------------------------------------------------------------

    def set_create_security_group_responses(tuples),
      do: set_responses(:create_security_group, tuples)

    def set_describe_security_groups_responses(funcs),
      do: set_responses(:describe_security_groups, Enum.map(funcs, &{"*", &1}))

    def set_delete_security_group_responses(tuples),
      do: set_responses(:delete_security_group, tuples)

    def set_authorize_security_group_ingress_responses(tuples),
      do: set_responses(:authorize_security_group_ingress, tuples)

    def set_revoke_security_group_ingress_responses(tuples),
      do: set_responses(:revoke_security_group_ingress, tuples)

    def set_authorize_security_group_egress_responses(tuples),
      do: set_responses(:authorize_security_group_egress, tuples)

    def set_revoke_security_group_egress_responses(tuples),
      do: set_responses(:revoke_security_group_egress, tuples)

    def set_describe_vpcs_responses(funcs),
      do: set_responses(:describe_vpcs, Enum.map(funcs, &{"*", &1}))

    def set_describe_subnets_responses(funcs),
      do: set_responses(:describe_subnets, Enum.map(funcs, &{"*", &1}))

    def set_create_tags_responses(tuples), do: set_responses(:create_tags, tuples)

    # ---------------------------------------------------------------------------
    # Sandbox control
    # ---------------------------------------------------------------------------

    @spec disable_ec2_sandbox(map) :: :ok
    def disable_ec2_sandbox(_context) do
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
