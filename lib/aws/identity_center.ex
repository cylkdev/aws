defmodule AWS.IdentityCenter do
  @moduledoc """
  `AWS.IdentityCenter` provides an API for AWS IAM Identity Center (formerly AWS SSO).

  This module covers two underlying AWS services:

    - **`sso-admin`** — Permission sets and account assignments. Operations in this
      service require an Identity Center instance ARN, available via `list_instances/1`.

    - **`identitystore`** — Users and groups within the Identity Center identity store.
      Operations in this service require an Identity Store ID (the `identity_store_id`
      from `list_instances/1`).

  ## Shared Options

  The following options are available for most functions in this API:

    - `:region` - The AWS region. Defaults to `AWS.Config.region()`.

    - `:identity_center` - A keyword list of options used to configure the ExAws service.
      See `ExAws.Config.new/2` for available options.

    - `:sandbox` - A keyword list to override sandbox configuration.
        - `:enabled` - Whether sandbox mode is enabled.
        - `:mode` - `:local` or `:inline`.
        - `:scheme` - The sandbox scheme.
        - `:host` - The sandbox host.
        - `:port` - The sandbox port.

  ## Sandbox

  Set `sandbox: [enabled: true, mode: :inline]` to activate inline sandbox mode.

  ### Setup

  Add the following to your `test_helper.exs`:

      AWS.IdentityCenter.Sandbox.start_link()

  ### Usage

      setup do
        AWS.IdentityCenter.Sandbox.set_list_instances_responses([
          fn -> {:ok, %{instances: [%{instance_arn: "arn:aws:sso:::instance/ssoins-1", identity_store_id: "d-123"}]}} end
        ])
      end

      test "lists instances" do
        assert {:ok, %{instances: [%{instance_arn: _}]}} =
                 AWS.IdentityCenter.list_instances(sandbox: [enabled: true, mode: :inline])
      end
  """

  alias AWS.{Config, Error, Serializer}

  # ---------------------------------------------------------------------------
  # Instances (sso-admin)
  # ---------------------------------------------------------------------------

  @doc """
  Lists the IAM Identity Center instances accessible in the current AWS account.

  Returns instance ARNs and identity store IDs needed for other operations.
  """
  @spec list_instances(opts :: keyword()) ::
          {:ok, %{instances: list(map())}} | {:error, term()}
  def list_instances(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_instances_response(opts)
    else
      do_list_instances(opts)
    end
  end

  defp do_list_instances(opts) do
    build_sso_operation("ListInstances", %{})
    |> perform(:sso, opts)
    |> deserialize_response(opts, fn body ->
      %{instances: instances} = Serializer.deserialize(body)
      {:ok, %{instances: instances || []}}
    end)
  end

  # ---------------------------------------------------------------------------
  # Permission Sets (sso-admin)
  # ---------------------------------------------------------------------------

  @doc """
  Creates a permission set in the specified Identity Center instance.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `name` - The permission set name.
    * `opts` - Options including `:description`, `:session_duration` (ISO 8601, e.g. `"PT8H"`),
      `:relay_state`, plus shared options.
  """
  @spec create_permission_set(instance_arn :: String.t(), name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_permission_set(instance_arn, name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_permission_set_response(name, opts)
    else
      do_create_permission_set(instance_arn, name, opts)
    end
  end

  defp do_create_permission_set(instance_arn, name, opts) do
    data =
      %{"InstanceArn" => instance_arn, "Name" => name}
      |> maybe_put("Description", opts[:description])
      |> maybe_put("SessionDuration", opts[:session_duration])
      |> maybe_put("RelayState", opts[:relay_state])

    build_sso_operation("CreatePermissionSet", data)
    |> perform(:sso, opts)
    |> deserialize_response(opts, fn body ->
      %{permission_set: ps} = Serializer.deserialize(body)
      {:ok, ps}
    end)
  end

  @doc """
  Deletes a permission set.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `permission_set_arn` - The ARN of the permission set.
    * `opts` - Shared options.
  """
  @spec delete_permission_set(instance_arn :: String.t(), permission_set_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_permission_set(instance_arn, permission_set_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_permission_set_response(permission_set_arn, opts)
    else
      do_delete_permission_set(instance_arn, permission_set_arn, opts)
    end
  end

  defp do_delete_permission_set(instance_arn, permission_set_arn, opts) do
    build_sso_operation("DeletePermissionSet", %{
      "InstanceArn" => instance_arn,
      "PermissionSetArn" => permission_set_arn
    })
    |> perform(:sso, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Lists permission sets in an Identity Center instance.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `opts` - Options including `:max_results`, `:next_token`, plus shared options.
  """
  @spec list_permission_sets(instance_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{permission_sets: list(String.t())}} | {:error, term()}
  def list_permission_sets(instance_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_permission_sets_response(instance_arn, opts)
    else
      do_list_permission_sets(instance_arn, opts)
    end
  end

  defp do_list_permission_sets(instance_arn, opts) do
    data =
      %{"InstanceArn" => instance_arn}
      |> maybe_put("MaxResults", opts[:max_results])
      |> maybe_put("NextToken", opts[:next_token])

    build_sso_operation("ListPermissionSets", data)
    |> perform(:sso, opts)
    |> deserialize_response(opts, fn body ->
      %{permission_sets: arns} = Serializer.deserialize(body)
      {:ok, %{permission_sets: arns || []}}
    end)
  end

  @doc """
  Attaches an AWS managed policy to a permission set.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `permission_set_arn` - The ARN of the permission set.
    * `managed_policy_arn` - The ARN of the managed policy to attach.
    * `opts` - Shared options.
  """
  @spec attach_managed_policy_to_permission_set(
          instance_arn :: String.t(),
          permission_set_arn :: String.t(),
          managed_policy_arn :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def attach_managed_policy_to_permission_set(instance_arn, permission_set_arn, managed_policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_attach_managed_policy_to_permission_set_response(permission_set_arn, opts)
    else
      do_attach_managed_policy_to_permission_set(instance_arn, permission_set_arn, managed_policy_arn, opts)
    end
  end

  defp do_attach_managed_policy_to_permission_set(instance_arn, permission_set_arn, managed_policy_arn, opts) do
    build_sso_operation("AttachManagedPolicyToPermissionSet", %{
      "InstanceArn" => instance_arn,
      "PermissionSetArn" => permission_set_arn,
      "ManagedPolicyArn" => managed_policy_arn
    })
    |> perform(:sso, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Detaches a managed policy from a permission set.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `permission_set_arn` - The ARN of the permission set.
    * `managed_policy_arn` - The ARN of the managed policy to detach.
    * `opts` - Shared options.
  """
  @spec detach_managed_policy_from_permission_set(
          instance_arn :: String.t(),
          permission_set_arn :: String.t(),
          managed_policy_arn :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def detach_managed_policy_from_permission_set(instance_arn, permission_set_arn, managed_policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_detach_managed_policy_from_permission_set_response(permission_set_arn, opts)
    else
      do_detach_managed_policy_from_permission_set(instance_arn, permission_set_arn, managed_policy_arn, opts)
    end
  end

  defp do_detach_managed_policy_from_permission_set(instance_arn, permission_set_arn, managed_policy_arn, opts) do
    build_sso_operation("DetachManagedPolicyFromPermissionSet", %{
      "InstanceArn" => instance_arn,
      "PermissionSetArn" => permission_set_arn,
      "ManagedPolicyArn" => managed_policy_arn
    })
    |> perform(:sso, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Account Assignments (sso-admin)
  # ---------------------------------------------------------------------------

  @doc """
  Creates an assignment that grants a principal access to an AWS account
  using a specified permission set.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `assignment` - A map with the following keys:
        - `:target_id` - AWS account ID.
        - `:target_type` - `"AWS_ACCOUNT"`.
        - `:permission_set_arn` - The ARN of the permission set.
        - `:principal_type` - `"USER"` or `"GROUP"`.
        - `:principal_id` - The user or group ID.
    * `opts` - Shared options.
  """
  @spec create_account_assignment(instance_arn :: String.t(), assignment :: map(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_account_assignment(instance_arn, assignment, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_account_assignment_response(instance_arn, opts)
    else
      do_create_account_assignment(instance_arn, assignment, opts)
    end
  end

  defp do_create_account_assignment(instance_arn, assignment, opts) do
    data = %{
      "InstanceArn" => instance_arn,
      "TargetId" => assignment.target_id,
      "TargetType" => assignment.target_type,
      "PermissionSetArn" => assignment.permission_set_arn,
      "PrincipalType" => assignment.principal_type,
      "PrincipalId" => assignment.principal_id
    }

    build_sso_operation("CreateAccountAssignment", data)
    |> perform(:sso, opts)
    |> deserialize_response(opts, fn body ->
      %{account_assignment_creation_status: status} = Serializer.deserialize(body)
      {:ok, status}
    end)
  end

  @doc """
  Deletes an account assignment.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `assignment` - Same shape as in `create_account_assignment/3`.
    * `opts` - Shared options.
  """
  @spec delete_account_assignment(instance_arn :: String.t(), assignment :: map(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def delete_account_assignment(instance_arn, assignment, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_account_assignment_response(instance_arn, opts)
    else
      do_delete_account_assignment(instance_arn, assignment, opts)
    end
  end

  defp do_delete_account_assignment(instance_arn, assignment, opts) do
    data = %{
      "InstanceArn" => instance_arn,
      "TargetId" => assignment.target_id,
      "TargetType" => assignment.target_type,
      "PermissionSetArn" => assignment.permission_set_arn,
      "PrincipalType" => assignment.principal_type,
      "PrincipalId" => assignment.principal_id
    }

    build_sso_operation("DeleteAccountAssignment", data)
    |> perform(:sso, opts)
    |> deserialize_response(opts, fn body ->
      %{account_assignment_deletion_status: status} = Serializer.deserialize(body)
      {:ok, status}
    end)
  end

  # ---------------------------------------------------------------------------
  # Identity Store — Users (identitystore)
  # ---------------------------------------------------------------------------

  @doc """
  Creates a user in the Identity Center identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID (from `list_instances/1`).
    * `username` - The user's login name.
    * `opts` - Options including `:display_name`, `:given_name`, `:family_name`,
      `:emails` (list of `%{value: "...", type: "...", primary: true/false}`),
      plus shared options.
  """
  @spec create_identity_store_user(identity_store_id :: String.t(), username :: String.t(), opts :: keyword()) ::
          {:ok, %{user_id: String.t()}} | {:error, term()}
  def create_identity_store_user(identity_store_id, username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_identity_store_user_response(username, opts)
    else
      do_create_identity_store_user(identity_store_id, username, opts)
    end
  end

  defp do_create_identity_store_user(identity_store_id, username, opts) do
    data =
      %{"IdentityStoreId" => identity_store_id, "UserName" => username}
      |> maybe_put("DisplayName", opts[:display_name])
      |> maybe_put_name(opts[:given_name], opts[:family_name])
      |> maybe_put("Emails", opts[:emails])

    build_identitystore_operation("CreateUser", data)
    |> perform(:identitystore, opts)
    |> deserialize_response(opts, fn body ->
      result = Serializer.deserialize(body)
      {:ok, %{user_id: result[:user_id], identity_store_id: result[:identity_store_id]}}
    end)
  end

  @doc """
  Deletes a user from the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `user_id` - The user ID.
    * `opts` - Shared options.
  """
  @spec delete_identity_store_user(identity_store_id :: String.t(), user_id :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_identity_store_user(identity_store_id, user_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_identity_store_user_response(user_id, opts)
    else
      do_delete_identity_store_user(identity_store_id, user_id, opts)
    end
  end

  defp do_delete_identity_store_user(identity_store_id, user_id, opts) do
    build_identitystore_operation("DeleteUser", %{
      "IdentityStoreId" => identity_store_id,
      "UserId" => user_id
    })
    |> perform(:identitystore, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Lists users in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `opts` - Options including `:max_results`, `:next_token`, plus shared options.
  """
  @spec list_identity_store_users(identity_store_id :: String.t(), opts :: keyword()) ::
          {:ok, %{users: list(map())}} | {:error, term()}
  def list_identity_store_users(identity_store_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_identity_store_users_response(identity_store_id, opts)
    else
      do_list_identity_store_users(identity_store_id, opts)
    end
  end

  defp do_list_identity_store_users(identity_store_id, opts) do
    data =
      %{"IdentityStoreId" => identity_store_id}
      |> maybe_put("MaxResults", opts[:max_results])
      |> maybe_put("NextToken", opts[:next_token])

    build_identitystore_operation("ListUsers", data)
    |> perform(:identitystore, opts)
    |> deserialize_response(opts, fn body ->
      %{users: users} = Serializer.deserialize(body)
      {:ok, %{users: users || []}}
    end)
  end

  # ---------------------------------------------------------------------------
  # Identity Store — Groups (identitystore)
  # ---------------------------------------------------------------------------

  @doc """
  Creates a group in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `display_name` - The group display name.
    * `opts` - Options including `:description`, plus shared options.
  """
  @spec create_identity_store_group(identity_store_id :: String.t(), display_name :: String.t(), opts :: keyword()) ::
          {:ok, %{group_id: String.t()}} | {:error, term()}
  def create_identity_store_group(identity_store_id, display_name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_identity_store_group_response(display_name, opts)
    else
      do_create_identity_store_group(identity_store_id, display_name, opts)
    end
  end

  defp do_create_identity_store_group(identity_store_id, display_name, opts) do
    data =
      %{"IdentityStoreId" => identity_store_id, "DisplayName" => display_name}
      |> maybe_put("Description", opts[:description])

    build_identitystore_operation("CreateGroup", data)
    |> perform(:identitystore, opts)
    |> deserialize_response(opts, fn body ->
      result = Serializer.deserialize(body)
      {:ok, %{group_id: result[:group_id], identity_store_id: result[:identity_store_id]}}
    end)
  end

  @doc """
  Deletes a group from the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `group_id` - The group ID.
    * `opts` - Shared options.
  """
  @spec delete_identity_store_group(identity_store_id :: String.t(), group_id :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_identity_store_group(identity_store_id, group_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_identity_store_group_response(group_id, opts)
    else
      do_delete_identity_store_group(identity_store_id, group_id, opts)
    end
  end

  defp do_delete_identity_store_group(identity_store_id, group_id, opts) do
    build_identitystore_operation("DeleteGroup", %{
      "IdentityStoreId" => identity_store_id,
      "GroupId" => group_id
    })
    |> perform(:identitystore, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Lists groups in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `opts` - Options including `:max_results`, `:next_token`, plus shared options.
  """
  @spec list_identity_store_groups(identity_store_id :: String.t(), opts :: keyword()) ::
          {:ok, %{groups: list(map())}} | {:error, term()}
  def list_identity_store_groups(identity_store_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_identity_store_groups_response(identity_store_id, opts)
    else
      do_list_identity_store_groups(identity_store_id, opts)
    end
  end

  defp do_list_identity_store_groups(identity_store_id, opts) do
    data =
      %{"IdentityStoreId" => identity_store_id}
      |> maybe_put("MaxResults", opts[:max_results])
      |> maybe_put("NextToken", opts[:next_token])

    build_identitystore_operation("ListGroups", data)
    |> perform(:identitystore, opts)
    |> deserialize_response(opts, fn body ->
      %{groups: groups} = Serializer.deserialize(body)
      {:ok, %{groups: groups || []}}
    end)
  end

  @doc """
  Adds a user to a group in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `group_id` - The group ID.
    * `user_id` - The user ID.
    * `opts` - Shared options.
  """
  @spec create_group_membership(
          identity_store_id :: String.t(),
          group_id :: String.t(),
          user_id :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{membership_id: String.t()}} | {:error, term()}
  def create_group_membership(identity_store_id, group_id, user_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_group_membership_response(group_id, opts)
    else
      do_create_group_membership(identity_store_id, group_id, user_id, opts)
    end
  end

  defp do_create_group_membership(identity_store_id, group_id, user_id, opts) do
    build_identitystore_operation("CreateGroupMembership", %{
      "IdentityStoreId" => identity_store_id,
      "GroupId" => group_id,
      "MemberId" => %{"UserId" => user_id}
    })
    |> perform(:identitystore, opts)
    |> deserialize_response(opts, fn body ->
      result = Serializer.deserialize(body)
      {:ok, %{membership_id: result[:membership_id], identity_store_id: result[:identity_store_id]}}
    end)
  end

  @doc """
  Removes a user from a group in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `membership_id` - The membership ID (from `create_group_membership/4`).
    * `opts` - Shared options.
  """
  @spec delete_group_membership(identity_store_id :: String.t(), membership_id :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_group_membership(identity_store_id, membership_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_group_membership_response(membership_id, opts)
    else
      do_delete_group_membership(identity_store_id, membership_id, opts)
    end
  end

  defp do_delete_group_membership(identity_store_id, membership_id, opts) do
    build_identitystore_operation("DeleteGroupMembership", %{
      "IdentityStoreId" => identity_store_id,
      "MembershipId" => membership_id
    })
    |> perform(:identitystore, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Sandbox delegation
  # ---------------------------------------------------------------------------

  defp inline_sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    sandbox_enabled = sandbox_opts[:enabled] || Config.sandbox_enabled?()
    sandbox_mode = sandbox_opts[:mode] || Config.sandbox_mode()

    sandbox_enabled and sandbox_mode === :inline and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    @doc false
    defdelegate sandbox_disabled?, to: AWS.IdentityCenter.Sandbox

    # Instances
    @doc false
    defdelegate sandbox_list_instances_response(opts), to: AWS.IdentityCenter.Sandbox, as: :list_instances_response

    # Permission Sets
    @doc false
    defdelegate sandbox_create_permission_set_response(name, opts), to: AWS.IdentityCenter.Sandbox, as: :create_permission_set_response
    @doc false
    defdelegate sandbox_delete_permission_set_response(arn, opts), to: AWS.IdentityCenter.Sandbox, as: :delete_permission_set_response
    @doc false
    defdelegate sandbox_list_permission_sets_response(instance_arn, opts), to: AWS.IdentityCenter.Sandbox, as: :list_permission_sets_response
    @doc false
    defdelegate sandbox_attach_managed_policy_to_permission_set_response(ps_arn, opts), to: AWS.IdentityCenter.Sandbox, as: :attach_managed_policy_to_permission_set_response
    @doc false
    defdelegate sandbox_detach_managed_policy_from_permission_set_response(ps_arn, opts), to: AWS.IdentityCenter.Sandbox, as: :detach_managed_policy_from_permission_set_response

    # Account Assignments
    @doc false
    defdelegate sandbox_create_account_assignment_response(instance_arn, opts), to: AWS.IdentityCenter.Sandbox, as: :create_account_assignment_response
    @doc false
    defdelegate sandbox_delete_account_assignment_response(instance_arn, opts), to: AWS.IdentityCenter.Sandbox, as: :delete_account_assignment_response

    # Identity Store — Users
    @doc false
    defdelegate sandbox_create_identity_store_user_response(username, opts), to: AWS.IdentityCenter.Sandbox, as: :create_identity_store_user_response
    @doc false
    defdelegate sandbox_delete_identity_store_user_response(user_id, opts), to: AWS.IdentityCenter.Sandbox, as: :delete_identity_store_user_response
    @doc false
    defdelegate sandbox_list_identity_store_users_response(store_id, opts), to: AWS.IdentityCenter.Sandbox, as: :list_identity_store_users_response

    # Identity Store — Groups
    @doc false
    defdelegate sandbox_create_identity_store_group_response(name, opts), to: AWS.IdentityCenter.Sandbox, as: :create_identity_store_group_response
    @doc false
    defdelegate sandbox_delete_identity_store_group_response(group_id, opts), to: AWS.IdentityCenter.Sandbox, as: :delete_identity_store_group_response
    @doc false
    defdelegate sandbox_list_identity_store_groups_response(store_id, opts), to: AWS.IdentityCenter.Sandbox, as: :list_identity_store_groups_response
    @doc false
    defdelegate sandbox_create_group_membership_response(group_id, opts), to: AWS.IdentityCenter.Sandbox, as: :create_group_membership_response
    @doc false
    defdelegate sandbox_delete_group_membership_response(membership_id, opts), to: AWS.IdentityCenter.Sandbox, as: :delete_group_membership_response
  else
    defp sandbox_disabled?, do: true

    defp sandbox_list_instances_response(_), do: raise("sandbox not available")
    defp sandbox_create_permission_set_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_permission_set_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_permission_sets_response(_, _), do: raise("sandbox not available")
    defp sandbox_attach_managed_policy_to_permission_set_response(_, _), do: raise("sandbox not available")
    defp sandbox_detach_managed_policy_from_permission_set_response(_, _), do: raise("sandbox not available")
    defp sandbox_create_account_assignment_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_account_assignment_response(_, _), do: raise("sandbox not available")
    defp sandbox_create_identity_store_user_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_identity_store_user_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_identity_store_users_response(_, _), do: raise("sandbox not available")
    defp sandbox_create_identity_store_group_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_identity_store_group_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_identity_store_groups_response(_, _), do: raise("sandbox not available")
    defp sandbox_create_group_membership_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_group_membership_response(_, _), do: raise("sandbox not available")
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp perform(operation, service, opts) do
    ExAws.Operation.perform(operation, service_config(service, opts))
  end

  defp service_config(service, opts) do
    {ic_opts, opts} = Keyword.pop(opts, :identity_center, [])
    {sandbox_opts, _opts} = Keyword.pop(opts, :sandbox, [])

    overrides =
      ic_opts
      |> Keyword.put_new(:region, opts[:region] || Config.region())
      |> configure_endpoint(sandbox_opts)

    ExAws.Config.new(service, overrides)
  end

  defp configure_endpoint(ic_opts, sandbox_opts) do
    sandbox_enabled = sandbox_opts[:enabled] || Config.sandbox_enabled?()
    sandbox_mode = sandbox_opts[:mode] || Config.sandbox_mode()

    if sandbox_enabled and sandbox_mode === :local do
      ic_opts
      |> Keyword.put(:scheme, Config.sandbox_scheme())
      |> Keyword.put(:host, Config.sandbox_host())
      |> Keyword.put(:port, Config.sandbox_port())
      |> Keyword.put_new(:access_key_id, "test")
      |> Keyword.put_new(:secret_access_key, "test")
    else
      maybe_put_credentials(ic_opts)
    end
  end

  defp maybe_put_credentials(opts) do
    opts
    |> Keyword.put_new(:access_key_id, Config.access_key_id())
    |> Keyword.put_new(:secret_access_key, Config.secret_access_key())
  end

  defp deserialize_response({:ok, response}, _opts, func) do
    case func.(response) do
      {:error, _} = error -> error
      {:ok, _} = ok -> ok
      result -> {:ok, result}
    end
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code in 400..499 do
    {:error, Error.not_found("resource not found.", %{response: response}, opts)}
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code >= 500 do
    {:error, Error.service_unavailable("service temporarily unavailable", %{response: response}, opts)}
  end

  defp deserialize_response({:error, reason}, opts, _func) do
    {:error, Error.internal_server_error("internal server error", %{reason: reason}, opts)}
  end

  defp build_sso_operation(action, data) do
    %ExAws.Operation.JSON{
      http_method: :post,
      service: :sso,
      headers: [
        {"x-amz-target", "SWBExternalService.#{action}"},
        {"content-type", "application/x-amz-json-1.1"}
      ],
      data: data
    }
  end

  defp build_identitystore_operation(action, data) do
    %ExAws.Operation.JSON{
      http_method: :post,
      service: :identitystore,
      headers: [
        {"x-amz-target", "AmazonIdentityStore.#{action}"},
        {"content-type", "application/x-amz-json-1.1"}
      ],
      data: data
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_name(data, nil, nil), do: data
  defp maybe_put_name(data, given, family) do
    name =
      %{}
      |> maybe_put("GivenName", given)
      |> maybe_put("FamilyName", family)

    Map.put(data, "Name", name)
  end
end
