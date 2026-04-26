if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.Organizations.Sandbox do
    @moduledoc false

    @registry :aws_organizations_sandbox
    @state "state"
    @disabled "disabled"
    @sleep 10
    @keys :unique

    def start_link do
      Registry.start_link(keys: @keys, name: @registry)
    end

    # Response retrieval functions — Organization

    def create_organization_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:create_organization, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def delete_organization_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:delete_organization, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def describe_organization_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_organization, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response retrieval functions — Organizational Units

    def create_organizational_unit_response(name, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:create_organizational_unit, name, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def delete_organizational_unit_response(ou_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:delete_organizational_unit, ou_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def list_organizational_units_for_parent_response(parent_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:list_organizational_units_for_parent, parent_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response retrieval functions — Accounts

    def create_account_response(name, opts) do
      doc_examples = ["fn -> ...", "fn (email) -> ...", "fn (email, opts) -> ..."]
      func = find!(:create_account, name, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def describe_create_account_status_response(request_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_create_account_status, request_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def move_account_response(account_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:move_account, account_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def close_account_response(account_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:close_account, account_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def list_accounts_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:list_accounts, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response retrieval functions — Roots

    def list_roots_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:list_roots, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response retrieval functions — Delegated administrators / service access

    def register_delegated_administrator_response(account_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:register_delegated_administrator, account_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def enable_aws_service_access_response(service_principal, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:enable_aws_service_access, service_principal, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def list_delegated_administrators_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:list_delegated_administrators, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def list_aws_service_access_for_organization_response(opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:list_aws_service_access_for_organization, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def list_parents_response(child_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:list_parents, child_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def describe_account_response(account_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_account, account_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def describe_organizational_unit_response(ou_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:describe_organizational_unit, ou_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def update_organizational_unit_response(ou_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:update_organizational_unit, ou_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def disable_aws_service_access_response(service_principal, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:disable_aws_service_access, service_principal, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def deregister_delegated_administrator_response(account_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:deregister_delegated_administrator, account_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def list_children_response(parent_id, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:list_children, parent_id, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response registration functions

    def set_create_organization_responses(funcs),
      do: set_responses(:create_organization, Enum.map(funcs, fn f -> {"*", f} end))

    def set_delete_organization_responses(funcs),
      do: set_responses(:delete_organization, Enum.map(funcs, fn f -> {"*", f} end))

    def set_describe_organization_responses(funcs),
      do: set_responses(:describe_organization, Enum.map(funcs, fn f -> {"*", f} end))

    def set_create_organizational_unit_responses(tuples),
      do: set_responses(:create_organizational_unit, tuples)

    def set_delete_organizational_unit_responses(tuples),
      do: set_responses(:delete_organizational_unit, tuples)

    def set_list_organizational_units_for_parent_responses(tuples),
      do: set_responses(:list_organizational_units_for_parent, tuples)

    def set_create_account_responses(tuples), do: set_responses(:create_account, tuples)

    def set_describe_create_account_status_responses(tuples),
      do: set_responses(:describe_create_account_status, tuples)

    def set_move_account_responses(tuples), do: set_responses(:move_account, tuples)
    def set_close_account_responses(tuples), do: set_responses(:close_account, tuples)

    def set_list_accounts_responses(funcs),
      do: set_responses(:list_accounts, Enum.map(funcs, fn f -> {"*", f} end))

    def set_list_roots_responses(funcs),
      do: set_responses(:list_roots, Enum.map(funcs, fn f -> {"*", f} end))

    def set_register_delegated_administrator_responses(tuples),
      do: set_responses(:register_delegated_administrator, tuples)

    def set_enable_aws_service_access_responses(tuples),
      do: set_responses(:enable_aws_service_access, tuples)

    def set_list_delegated_administrators_responses(funcs),
      do: set_responses(:list_delegated_administrators, Enum.map(funcs, fn f -> {"*", f} end))

    def set_list_aws_service_access_for_organization_responses(funcs),
      do:
        set_responses(
          :list_aws_service_access_for_organization,
          Enum.map(funcs, fn f -> {"*", f} end)
        )

    def set_list_parents_responses(tuples), do: set_responses(:list_parents, tuples)

    def set_describe_account_responses(tuples), do: set_responses(:describe_account, tuples)

    def set_describe_organizational_unit_responses(tuples),
      do: set_responses(:describe_organizational_unit, tuples)

    def set_update_organizational_unit_responses(tuples),
      do: set_responses(:update_organizational_unit, tuples)

    def set_disable_aws_service_access_responses(tuples),
      do: set_responses(:disable_aws_service_access, tuples)

    def set_deregister_delegated_administrator_responses(tuples),
      do: set_responses(:deregister_delegated_administrator, tuples)

    def set_list_children_responses(tuples), do: set_responses(:list_children, tuples)

    # Sandbox control

    @spec disable_organizations_sandbox(map) :: :ok
    def disable_organizations_sandbox(_context) do
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
