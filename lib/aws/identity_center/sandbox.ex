defmodule AWS.IdentityCenter.Sandbox do
  @moduledoc false

  @registry :aws_identity_center_sandbox
  @state "state"
  @disabled "disabled"
  @sleep 10
  @keys :unique

  def start_link do
    Registry.start_link(keys: @keys, name: @registry)
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Instances
  # ---------------------------------------------------------------------------

  def list_instances_response(opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_instances, "*", doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Permission Sets
  # ---------------------------------------------------------------------------

  def create_permission_set_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_permission_set, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_permission_set_response(arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_permission_set, arn, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_permission_sets_response(instance_arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_permission_sets, instance_arn, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def attach_managed_policy_to_permission_set_response(ps_arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:attach_managed_policy_to_permission_set, ps_arn, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def detach_managed_policy_from_permission_set_response(ps_arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:detach_managed_policy_from_permission_set, ps_arn, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Account Assignments
  # ---------------------------------------------------------------------------

  def create_account_assignment_response(instance_arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_account_assignment, instance_arn, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_account_assignment_response(instance_arn, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_account_assignment, instance_arn, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Identity Store Users
  # ---------------------------------------------------------------------------

  def create_identity_store_user_response(username, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_identity_store_user, username, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_identity_store_user_response(user_id, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_identity_store_user, user_id, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_identity_store_users_response(store_id, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_identity_store_users, store_id, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response retrieval — Identity Store Groups
  # ---------------------------------------------------------------------------

  def create_identity_store_group_response(name, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_identity_store_group, name, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_identity_store_group_response(group_id, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_identity_store_group, group_id, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def list_identity_store_groups_response(store_id, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:list_identity_store_groups, store_id, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def create_group_membership_response(group_id, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:create_group_membership, group_id, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  def delete_group_membership_response(membership_id, opts) do
    doc_examples = ["fn -> ...", "fn (opts) -> ..."]
    func = find!(:delete_group_membership, membership_id, doc_examples)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(opts)
      _ -> raise_unsupported_arity(func, doc_examples)
    end
  end

  # ---------------------------------------------------------------------------
  # Response registration
  # ---------------------------------------------------------------------------

  def set_list_instances_responses(funcs), do: set_responses(:list_instances, Enum.map(funcs, &{"*", &1}))

  def set_create_permission_set_responses(tuples), do: set_responses(:create_permission_set, tuples)
  def set_delete_permission_set_responses(tuples), do: set_responses(:delete_permission_set, tuples)
  def set_list_permission_sets_responses(tuples), do: set_responses(:list_permission_sets, tuples)
  def set_attach_managed_policy_to_permission_set_responses(tuples), do: set_responses(:attach_managed_policy_to_permission_set, tuples)
  def set_detach_managed_policy_from_permission_set_responses(tuples), do: set_responses(:detach_managed_policy_from_permission_set, tuples)

  def set_create_account_assignment_responses(tuples), do: set_responses(:create_account_assignment, tuples)
  def set_delete_account_assignment_responses(tuples), do: set_responses(:delete_account_assignment, tuples)

  def set_create_identity_store_user_responses(tuples), do: set_responses(:create_identity_store_user, tuples)
  def set_delete_identity_store_user_responses(tuples), do: set_responses(:delete_identity_store_user, tuples)
  def set_list_identity_store_users_responses(tuples), do: set_responses(:list_identity_store_users, tuples)

  def set_create_identity_store_group_responses(tuples), do: set_responses(:create_identity_store_group, tuples)
  def set_delete_identity_store_group_responses(tuples), do: set_responses(:delete_identity_store_group, tuples)
  def set_list_identity_store_groups_responses(tuples), do: set_responses(:list_identity_store_groups, tuples)
  def set_create_group_membership_responses(tuples), do: set_responses(:create_group_membership, tuples)
  def set_delete_group_membership_responses(tuples), do: set_responses(:delete_group_membership, tuples)

  # ---------------------------------------------------------------------------
  # Sandbox control
  # ---------------------------------------------------------------------------

  @spec disable_identity_center_sandbox(map) :: :ok
  def disable_identity_center_sandbox(_context) do
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
