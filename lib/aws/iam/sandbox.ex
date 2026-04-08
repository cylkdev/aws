defmodule AWS.IAM.Sandbox do
  @moduledoc false

  @registry :aws_iam_sandbox
  @state "state"
  @disabled "disabled"
  @sleep 10
  @keys :unique

  def start_link do
    Registry.start_link(keys: @keys, name: @registry)
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Users
  # ---------------------------------------------------------------------------

  def create_user_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_user, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def get_user_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:get_user, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_users_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_users, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_user_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_user, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Access Keys
  # ---------------------------------------------------------------------------

  def create_access_key_response(username, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_access_key, username, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_access_keys_response(username, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_access_keys, username, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_access_key_response(key_id, _username, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_access_key, key_id, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Groups
  # ---------------------------------------------------------------------------

  def create_group_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_group, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_groups_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_groups, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_group_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_group, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Group membership
  # ---------------------------------------------------------------------------

  def add_user_to_group_response(group, _user, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:add_user_to_group, group, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def remove_user_from_group_response(group, _user, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:remove_user_from_group, group, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Roles
  # ---------------------------------------------------------------------------

  def create_role_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_role, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def get_role_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:get_role, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_roles_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_roles, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_role_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_role, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Policies
  # ---------------------------------------------------------------------------

  def create_policy_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_policy, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def get_policy_response(arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:get_policy, arn, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_policies_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_policies, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_policy_response(arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_policy, arn, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Attachments
  # ---------------------------------------------------------------------------

  def attach_role_policy_response(role, _arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:attach_role_policy, role, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def detach_role_policy_response(role, _arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:detach_role_policy, role, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_attached_role_policies_response(role, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_attached_role_policies, role, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def attach_user_policy_response(user, _arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:attach_user_policy, user, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def detach_user_policy_response(user, _arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:detach_user_policy, user, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def attach_group_policy_response(group, _arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:attach_group_policy, group, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def detach_group_policy_response(group, _arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:detach_group_policy, group, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response registration
  # ---------------------------------------------------------------------------

  def set_create_user_responses(tuples), do: set_responses(:create_user, tuples)
  def set_get_user_responses(tuples), do: set_responses(:get_user, tuples)
  def set_list_users_responses(funcs), do: set_responses(:list_users, Enum.map(funcs, &{"*", &1}))
  def set_delete_user_responses(tuples), do: set_responses(:delete_user, tuples)

  def set_create_access_key_responses(tuples), do: set_responses(:create_access_key, tuples)
  def set_list_access_keys_responses(tuples), do: set_responses(:list_access_keys, tuples)
  def set_delete_access_key_responses(tuples), do: set_responses(:delete_access_key, tuples)

  def set_create_group_responses(tuples), do: set_responses(:create_group, tuples)
  def set_list_groups_responses(funcs), do: set_responses(:list_groups, Enum.map(funcs, &{"*", &1}))
  def set_delete_group_responses(tuples), do: set_responses(:delete_group, tuples)

  def set_add_user_to_group_responses(tuples), do: set_responses(:add_user_to_group, tuples)
  def set_remove_user_from_group_responses(tuples), do: set_responses(:remove_user_from_group, tuples)

  def set_create_role_responses(tuples), do: set_responses(:create_role, tuples)
  def set_get_role_responses(tuples), do: set_responses(:get_role, tuples)
  def set_list_roles_responses(funcs), do: set_responses(:list_roles, Enum.map(funcs, &{"*", &1}))
  def set_delete_role_responses(tuples), do: set_responses(:delete_role, tuples)

  def set_create_policy_responses(tuples), do: set_responses(:create_policy, tuples)
  def set_get_policy_responses(tuples), do: set_responses(:get_policy, tuples)
  def set_list_policies_responses(funcs), do: set_responses(:list_policies, Enum.map(funcs, &{"*", &1}))
  def set_delete_policy_responses(tuples), do: set_responses(:delete_policy, tuples)

  def set_attach_role_policy_responses(tuples), do: set_responses(:attach_role_policy, tuples)
  def set_detach_role_policy_responses(tuples), do: set_responses(:detach_role_policy, tuples)
  def set_list_attached_role_policies_responses(tuples), do: set_responses(:list_attached_role_policies, tuples)
  def set_attach_user_policy_responses(tuples), do: set_responses(:attach_user_policy, tuples)
  def set_detach_user_policy_responses(tuples), do: set_responses(:detach_user_policy, tuples)
  def set_attach_group_policy_responses(tuples), do: set_responses(:attach_group_policy, tuples)
  def set_detach_group_policy_responses(tuples), do: set_responses(:detach_group_policy, tuples)

  # ---------------------------------------------------------------------------
  # Sandbox control
  # ---------------------------------------------------------------------------

  @spec disable_iam_sandbox(map) :: :ok
  def disable_iam_sandbox(_context) do
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
