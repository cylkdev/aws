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

  Credentials and region are flat top-level opts on every call (ex_aws shape).
  Each accepts a literal, a source tuple, or a list of sources (first
  non-nil wins):

    - `:access_key_id`, `:secret_access_key`, `:security_token`, `:region` -
      Sources: literal binary, `{:system, "ENV"}`, `:instance_role`,
      `:ecs_task_role`, `{:awscli, profile}` / `{:awscli, profile, ttl}`,
      a module, or a list of any of these. Map-returning sources merge
      into the outer config. `{:awscli, _}` is not in the default chain —
      callers opt in explicitly.

  The following options are also available:

    - `:identity_center` - A keyword list of Identity Center endpoint
      overrides. Supported keys: `:scheme`, `:host`, `:port`. Credentials
      are not read from this sub-list; use the top-level keys above.

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

  alias AWS.{Client, Config, Error, Serializer}
  alias AWS.IdentityCenter.Operation

  @content_type "application/x-amz-json-1.1"

  @sso_service "sso"
  @sso_target_prefix "SWBExternalService"

  @identitystore_service "identitystore"
  @identitystore_target_prefix "AWSIdentityStore"

  @override_keys [:headers, :body, :http, :url]

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
    perform(:sso, "ListInstances", %{}, opts)
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

    perform(:sso, "CreatePermissionSet", data, opts)
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
  @spec delete_permission_set(
          instance_arn :: String.t(),
          permission_set_arn :: String.t(),
          opts :: keyword()
        ) ::
          {:ok, %{}} | {:error, term()}
  def delete_permission_set(instance_arn, permission_set_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_permission_set_response(permission_set_arn, opts)
    else
      do_delete_permission_set(instance_arn, permission_set_arn, opts)
    end
  end

  defp do_delete_permission_set(instance_arn, permission_set_arn, opts) do
    perform(
      :sso,
      "DeletePermissionSet",
      %{
        "InstanceArn" => instance_arn,
        "PermissionSetArn" => permission_set_arn
      },
      opts
    )
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Lists permission sets in an Identity Center instance.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `opts` - Options including `:max_results`, `:next_token`, plus shared options.
  """
  @spec list_permission_sets(instance_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{permission_sets: list(String.t()), next_token: String.t() | nil}}
          | {:error, term()}
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

    perform(:sso, "ListPermissionSets", data, opts)
    |> deserialize_response(opts, fn body ->
      deserialized = Serializer.deserialize(body)

      {:ok,
       %{
         permission_sets: deserialized[:permission_sets] || [],
         next_token: deserialized[:next_token]
       }}
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
  def attach_managed_policy_to_permission_set(
        instance_arn,
        permission_set_arn,
        managed_policy_arn,
        opts \\ []
      ) do
    if inline_sandbox?(opts) do
      sandbox_attach_managed_policy_to_permission_set_response(permission_set_arn, opts)
    else
      do_attach_managed_policy_to_permission_set(
        instance_arn,
        permission_set_arn,
        managed_policy_arn,
        opts
      )
    end
  end

  defp do_attach_managed_policy_to_permission_set(
         instance_arn,
         permission_set_arn,
         managed_policy_arn,
         opts
       ) do
    perform(
      :sso,
      "AttachManagedPolicyToPermissionSet",
      %{
        "InstanceArn" => instance_arn,
        "PermissionSetArn" => permission_set_arn,
        "ManagedPolicyArn" => managed_policy_arn
      },
      opts
    )
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Describes a single permission set.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `permission_set_arn` - The ARN of the permission set.
    * `opts` - Shared options.
  """
  @spec describe_permission_set(
          instance_arn :: String.t(),
          permission_set_arn :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{permission_set: map()}} | {:error, term()}
  def describe_permission_set(instance_arn, permission_set_arn, opts \\ []) do
    perform(
      :sso,
      "DescribePermissionSet",
      %{
        "InstanceArn" => instance_arn,
        "PermissionSetArn" => permission_set_arn
      },
      opts
    )
    |> deserialize_response(opts, fn body ->
      %{permission_set: ps} = Serializer.deserialize(body)
      {:ok, %{permission_set: ps}}
    end)
  end

  @doc """
  Returns the inline policy document attached to a permission set.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `permission_set_arn` - The ARN of the permission set.
    * `opts` - Shared options.

  Returns `{:ok, %{inline_policy: map() | nil}}`. The policy is decoded from
  the JSON string AWS returns. `nil` when no inline policy is attached.
  """
  @spec get_inline_policy_for_permission_set(
          instance_arn :: String.t(),
          permission_set_arn :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{inline_policy: map() | nil}} | {:error, term()}
  def get_inline_policy_for_permission_set(instance_arn, permission_set_arn, opts \\ []) do
    perform(
      :sso,
      "GetInlinePolicyForPermissionSet",
      %{
        "InstanceArn" => instance_arn,
        "PermissionSetArn" => permission_set_arn
      },
      opts
    )
    |> deserialize_response(opts, fn body ->
      result = Serializer.deserialize(body)

      decoded =
        case result[:inline_policy] do
          nil -> nil
          "" -> nil
          json when is_binary(json) -> :json.decode(json)
        end

      {:ok, %{inline_policy: decoded}}
    end)
  end

  @doc """
  Lists the AWS managed policies attached to a permission set.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `permission_set_arn` - The ARN of the permission set.
    * `opts` - Options including `:max_results`, `:next_token`, plus shared options.

  Returns `{:ok, %{attached_managed_policies: [map()]}}` where each entry has
  `:arn` and `:name`.
  """
  @spec list_managed_policies_in_permission_set(
          instance_arn :: String.t(),
          permission_set_arn :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{attached_managed_policies: list(map())}} | {:error, term()}
  def list_managed_policies_in_permission_set(instance_arn, permission_set_arn, opts \\ []) do
    data =
      %{"InstanceArn" => instance_arn, "PermissionSetArn" => permission_set_arn}
      |> maybe_put("MaxResults", opts[:max_results])
      |> maybe_put("NextToken", opts[:next_token])

    perform(:sso, "ListManagedPoliciesInPermissionSet", data, opts)
    |> deserialize_response(opts, fn body ->
      result = Serializer.deserialize(body)
      {:ok, %{attached_managed_policies: result[:attached_managed_policies] || []}}
    end)
  end

  @doc """
  Lists the principals (users or groups) assigned to a permission set for a
  given AWS account.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `account_id` - The AWS account ID (the assignment target).
    * `permission_set_arn` - The ARN of the permission set.
    * `opts` - Options including `:max_results`, `:next_token`, plus shared options.

  Returns `{:ok, %{account_assignments: [map()]}}` where each entry has
  `:account_id`, `:permission_set_arn`, `:principal_id`, `:principal_type`.
  """
  @spec list_account_assignments(
          instance_arn :: String.t(),
          account_id :: String.t(),
          permission_set_arn :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{account_assignments: list(map())}} | {:error, term()}
  def list_account_assignments(instance_arn, account_id, permission_set_arn, opts \\ []) do
    data =
      %{
        "InstanceArn" => instance_arn,
        "AccountId" => account_id,
        "PermissionSetArn" => permission_set_arn
      }
      |> maybe_put("MaxResults", opts[:max_results])
      |> maybe_put("NextToken", opts[:next_token])

    perform(:sso, "ListAccountAssignments", data, opts)
    |> deserialize_response(opts, fn body ->
      result = Serializer.deserialize(body)
      {:ok, %{account_assignments: result[:account_assignments] || []}}
    end)
  end

  @doc """
  Lists the AWS account IDs to which a permission set is provisioned.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `permission_set_arn` - The ARN of the permission set.
    * `opts` - Options including `:max_results`, `:next_token`, plus shared options.
  """
  @spec list_accounts_for_provisioned_permission_set(
          instance_arn :: String.t(),
          permission_set_arn :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{account_ids: [String.t()]}} | {:error, term()}
  def list_accounts_for_provisioned_permission_set(instance_arn, permission_set_arn, opts \\ []) do
    data =
      %{"InstanceArn" => instance_arn, "PermissionSetArn" => permission_set_arn}
      |> maybe_put("MaxResults", opts[:max_results])
      |> maybe_put("NextToken", opts[:next_token])

    perform(:sso, "ListAccountsForProvisionedPermissionSet", data, opts)
    |> deserialize_response(opts, fn body ->
      %{account_ids: ids} = Serializer.deserialize(body)
      {:ok, %{account_ids: ids || []}}
    end)
  end

  @doc """
  Attaches an inline policy document to a permission set.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `permission_set_arn` - The ARN of the permission set.
    * `policy` - The policy document as a map (will be JSON-encoded).
    * `opts` - Shared options.
  """
  @spec put_inline_policy_to_permission_set(
          instance_arn :: String.t(),
          permission_set_arn :: String.t(),
          policy :: map(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def put_inline_policy_to_permission_set(instance_arn, permission_set_arn, policy, opts \\ []) do
    perform(
      :sso,
      "PutInlinePolicyToPermissionSet",
      %{
        "InstanceArn" => instance_arn,
        "PermissionSetArn" => permission_set_arn,
        "InlinePolicy" => policy |> :json.encode() |> IO.iodata_to_binary()
      },
      opts
    )
    |> deserialize_response(opts, fn body -> {:ok, Serializer.deserialize(body)} end)
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
  def detach_managed_policy_from_permission_set(
        instance_arn,
        permission_set_arn,
        managed_policy_arn,
        opts \\ []
      ) do
    if inline_sandbox?(opts) do
      sandbox_detach_managed_policy_from_permission_set_response(permission_set_arn, opts)
    else
      do_detach_managed_policy_from_permission_set(
        instance_arn,
        permission_set_arn,
        managed_policy_arn,
        opts
      )
    end
  end

  defp do_detach_managed_policy_from_permission_set(
         instance_arn,
         permission_set_arn,
         managed_policy_arn,
         opts
       ) do
    perform(
      :sso,
      "DetachManagedPolicyFromPermissionSet",
      %{
        "InstanceArn" => instance_arn,
        "PermissionSetArn" => permission_set_arn,
        "ManagedPolicyArn" => managed_policy_arn
      },
      opts
    )
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
  @spec create_account_assignment(
          instance_arn :: String.t(),
          assignment :: map(),
          opts :: keyword()
        ) ::
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

    perform(:sso, "CreateAccountAssignment", data, opts)
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
  @spec delete_account_assignment(
          instance_arn :: String.t(),
          assignment :: map(),
          opts :: keyword()
        ) ::
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

    perform(:sso, "DeleteAccountAssignment", data, opts)
    |> deserialize_response(opts, fn body ->
      %{account_assignment_deletion_status: status} = Serializer.deserialize(body)
      {:ok, status}
    end)
  end

  @doc """
  Provisions a permission set to one or all accounts where it is assigned.

  ## Arguments

    * `instance_arn` - The ARN of the Identity Center instance.
    * `permission_set_arn` - The ARN of the permission set.
    * `opts` - Options including `:target_type` (defaults to
      `"ALL_PROVISIONED_ACCOUNTS"`; use `"AWS_ACCOUNT"` with `:target_id`
      to provision a single account) and `:target_id` (required when
      `:target_type` is `"AWS_ACCOUNT"`), plus shared options.

  Returns `{:ok, status}` where `status` is the
  `PermissionSetProvisioningStatus` map describing the async job.
  """
  @spec provision_permission_set(
          instance_arn :: String.t(),
          permission_set_arn :: String.t(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def provision_permission_set(instance_arn, permission_set_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_provision_permission_set_response(permission_set_arn, opts)
    else
      do_provision_permission_set(instance_arn, permission_set_arn, opts)
    end
  end

  defp do_provision_permission_set(instance_arn, permission_set_arn, opts) do
    data =
      %{
        "InstanceArn" => instance_arn,
        "PermissionSetArn" => permission_set_arn,
        "TargetType" => opts[:target_type] || "ALL_PROVISIONED_ACCOUNTS"
      }
      |> maybe_put("TargetId", opts[:target_id])

    perform(:sso, "ProvisionPermissionSet", data, opts)
    |> deserialize_response(opts, fn body ->
      %{permission_set_provisioning_status: status} = Serializer.deserialize(body)
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
  @spec create_identity_store_user(
          identity_store_id :: String.t(),
          username :: String.t(),
          opts :: keyword()
        ) ::
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

    perform(:identitystore, "CreateUser", data, opts)
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
  @spec delete_identity_store_user(
          identity_store_id :: String.t(),
          user_id :: String.t(),
          opts :: keyword()
        ) ::
          {:ok, %{}} | {:error, term()}
  def delete_identity_store_user(identity_store_id, user_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_identity_store_user_response(user_id, opts)
    else
      do_delete_identity_store_user(identity_store_id, user_id, opts)
    end
  end

  defp do_delete_identity_store_user(identity_store_id, user_id, opts) do
    perform(
      :identitystore,
      "DeleteUser",
      %{
        "IdentityStoreId" => identity_store_id,
        "UserId" => user_id
      },
      opts
    )
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Describes a user in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `user_id` - The user ID.
    * `opts` - Shared options.

  Returns `{:ok, map()}` containing the user's attributes.
  """
  @spec describe_identity_store_user(
          identity_store_id :: String.t(),
          user_id :: String.t(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def describe_identity_store_user(identity_store_id, user_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_identity_store_user_response(user_id, opts)
    else
      do_describe_identity_store_user(identity_store_id, user_id, opts)
    end
  end

  defp do_describe_identity_store_user(identity_store_id, user_id, opts) do
    perform(
      :identitystore,
      "DescribeUser",
      %{"IdentityStoreId" => identity_store_id, "UserId" => user_id},
      opts
    )
    |> deserialize_response(opts, fn body -> {:ok, Serializer.deserialize(body)} end)
  end

  @doc """
  Updates attributes of a user in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `user_id` - The user ID.
    * `opts` - Options specifying the attributes to update. Any of
      `:display_name`, `:given_name`, `:family_name`, and `:emails` that are
      provided are sent as `Operations` entries. Shared options are also
      accepted.

  Returns `{:ok, %{}}` on success.
  """
  @spec update_identity_store_user(
          identity_store_id :: String.t(),
          user_id :: String.t(),
          opts :: keyword()
        ) ::
          {:ok, %{}} | {:error, term()}
  def update_identity_store_user(identity_store_id, user_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_update_identity_store_user_response(user_id, opts)
    else
      do_update_identity_store_user(identity_store_id, user_id, opts)
    end
  end

  defp do_update_identity_store_user(identity_store_id, user_id, opts) do
    operations =
      []
      |> maybe_operation("displayName", opts[:display_name])
      |> maybe_operation("name.givenName", opts[:given_name])
      |> maybe_operation("name.familyName", opts[:family_name])
      |> maybe_operation("emails", opts[:emails])
      |> Enum.reverse()

    data = %{
      "IdentityStoreId" => identity_store_id,
      "UserId" => user_id,
      "Operations" => operations
    }

    perform(:identitystore, "UpdateUser", data, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Lists users in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `opts` - Options including `:max_results`, `:next_token`, plus shared options.
  """
  @spec list_identity_store_users(identity_store_id :: String.t(), opts :: keyword()) ::
          {:ok, %{users: list(map()), next_token: String.t() | nil}} | {:error, term()}
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

    perform(:identitystore, "ListUsers", data, opts)
    |> deserialize_response(opts, fn body ->
      result = Serializer.deserialize(body)
      {:ok, %{users: result[:users] || [], next_token: result[:next_token]}}
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
  @spec create_identity_store_group(
          identity_store_id :: String.t(),
          display_name :: String.t(),
          opts :: keyword()
        ) ::
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
      maybe_put(
        %{"IdentityStoreId" => identity_store_id, "DisplayName" => display_name},
        "Description",
        opts[:description]
      )

    perform(:identitystore, "CreateGroup", data, opts)
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
  @spec delete_identity_store_group(
          identity_store_id :: String.t(),
          group_id :: String.t(),
          opts :: keyword()
        ) ::
          {:ok, %{}} | {:error, term()}
  def delete_identity_store_group(identity_store_id, group_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_identity_store_group_response(group_id, opts)
    else
      do_delete_identity_store_group(identity_store_id, group_id, opts)
    end
  end

  defp do_delete_identity_store_group(identity_store_id, group_id, opts) do
    perform(
      :identitystore,
      "DeleteGroup",
      %{
        "IdentityStoreId" => identity_store_id,
        "GroupId" => group_id
      },
      opts
    )
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Describes a group in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `group_id` - The group ID.
    * `opts` - Shared options.

  Returns `{:ok, map()}` containing the group's attributes.
  """
  @spec describe_identity_store_group(
          identity_store_id :: String.t(),
          group_id :: String.t(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def describe_identity_store_group(identity_store_id, group_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_identity_store_group_response(group_id, opts)
    else
      do_describe_identity_store_group(identity_store_id, group_id, opts)
    end
  end

  defp do_describe_identity_store_group(identity_store_id, group_id, opts) do
    perform(
      :identitystore,
      "DescribeGroup",
      %{"IdentityStoreId" => identity_store_id, "GroupId" => group_id},
      opts
    )
    |> deserialize_response(opts, fn body -> {:ok, Serializer.deserialize(body)} end)
  end

  @doc """
  Lists groups in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `opts` - Options including `:max_results`, `:next_token`, plus shared options.
  """
  @spec list_identity_store_groups(identity_store_id :: String.t(), opts :: keyword()) ::
          {:ok, %{groups: list(map()), next_token: String.t() | nil}} | {:error, term()}
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

    perform(:identitystore, "ListGroups", data, opts)
    |> deserialize_response(opts, fn body ->
      result = Serializer.deserialize(body)
      {:ok, %{groups: result[:groups] || [], next_token: result[:next_token]}}
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
    perform(
      :identitystore,
      "CreateGroupMembership",
      %{
        "IdentityStoreId" => identity_store_id,
        "GroupId" => group_id,
        "MemberId" => %{"UserId" => user_id}
      },
      opts
    )
    |> deserialize_response(opts, fn body ->
      result = Serializer.deserialize(body)

      {:ok,
       %{membership_id: result[:membership_id], identity_store_id: result[:identity_store_id]}}
    end)
  end

  @doc """
  Removes a user from a group in the identity store.

  ## Arguments

    * `identity_store_id` - The identity store ID.
    * `membership_id` - The membership ID (from `create_group_membership/4`).
    * `opts` - Shared options.
  """
  @spec delete_group_membership(
          identity_store_id :: String.t(),
          membership_id :: String.t(),
          opts :: keyword()
        ) ::
          {:ok, %{}} | {:error, term()}
  def delete_group_membership(identity_store_id, membership_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_group_membership_response(membership_id, opts)
    else
      do_delete_group_membership(identity_store_id, membership_id, opts)
    end
  end

  defp do_delete_group_membership(identity_store_id, membership_id, opts) do
    perform(
      :identitystore,
      "DeleteGroupMembership",
      %{
        "IdentityStoreId" => identity_store_id,
        "MembershipId" => membership_id
      },
      opts
    )
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @doc false
  def build_operation(:sso, action, data, opts) do
    build_request(
      @sso_service,
      @sso_target_prefix,
      &"sso.#{&1}.amazonaws.com",
      action,
      data,
      opts
    )
  end

  def build_operation(:identitystore, action, data, opts) do
    build_request(
      @identitystore_service,
      @identitystore_target_prefix,
      &"identitystore.#{&1}.amazonaws.com",
      action,
      data,
      opts
    )
  end

  defp perform(subservice, action, data, opts) do
    with {:ok, op} <- build_operation(subservice, action, data, opts) do
      op
      |> Client.execute()
      |> decode_response()
    end
  end

  defp build_request(service, target_prefix, default_host_fn, action, data, opts) do
    with {:ok, config} <- Client.resolve_config(:identity_center, opts, default_host_fn) do
      op = %Operation{
        method: :post,
        url: Client.simple_url(config),
        headers: [
          {"content-type", @content_type},
          {"x-amz-target", "#{target_prefix}.#{action}"}
        ],
        body: encode_body(data),
        service: service,
        region: config.region,
        access_key_id: config.access_key_id,
        secret_access_key: config.secret_access_key,
        security_token: config.security_token,
        http: Keyword.get(opts, :http, [])
      }

      {:ok, apply_overrides(op, opts[:identity_center] || [])}
    end
  end

  defp apply_overrides(op, overrides) do
    Enum.reduce(@override_keys, op, fn key, acc ->
      case Keyword.fetch(overrides, key) do
        {:ok, value} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  defp encode_body(data) when map_size(data) === 0, do: "{}"
  defp encode_body(data), do: data |> :json.encode() |> IO.iodata_to_binary()

  defp decode_response({:ok, %{body: body}}), do: {:ok, decode_body(body)}

  defp decode_response({:error, {:http_error, status, body}}),
    do: {:error, {:http_error, status, decode_body(body)}}

  defp decode_response({:error, _reason} = err), do: err

  defp decode_body(""), do: %{}

  defp decode_body(binary) when is_binary(binary) do
    :json.decode(binary)
  rescue
    _ -> binary
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
    {:error,
     Error.service_unavailable("service temporarily unavailable", %{response: response}, opts)}
  end

  defp deserialize_response({:error, reason}, opts, _func) do
    {:error, Error.internal_server_error("internal server error", %{reason: reason}, opts)}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_operation(ops, _path, nil), do: ops

  defp maybe_operation(ops, path, value),
    do: [%{"AttributePath" => path, "AttributeValue" => value} | ops]

  defp maybe_put_name(data, nil, nil), do: data

  defp maybe_put_name(data, given, family) do
    name =
      %{}
      |> maybe_put("GivenName", given)
      |> maybe_put("FamilyName", family)

    Map.put(data, "Name", name)
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
    defdelegate sandbox_list_instances_response(opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :list_instances_response

    # Permission Sets
    @doc false
    defdelegate sandbox_create_permission_set_response(name, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :create_permission_set_response

    @doc false
    defdelegate sandbox_delete_permission_set_response(arn, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :delete_permission_set_response

    @doc false
    defdelegate sandbox_list_permission_sets_response(instance_arn, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :list_permission_sets_response

    @doc false
    defdelegate sandbox_attach_managed_policy_to_permission_set_response(ps_arn, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :attach_managed_policy_to_permission_set_response

    @doc false
    defdelegate sandbox_detach_managed_policy_from_permission_set_response(ps_arn, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :detach_managed_policy_from_permission_set_response

    # Account Assignments
    @doc false
    defdelegate sandbox_create_account_assignment_response(instance_arn, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :create_account_assignment_response

    @doc false
    defdelegate sandbox_delete_account_assignment_response(instance_arn, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :delete_account_assignment_response

    @doc false
    defdelegate sandbox_provision_permission_set_response(permission_set_arn, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :provision_permission_set_response

    # Identity Store — Users
    @doc false
    defdelegate sandbox_create_identity_store_user_response(username, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :create_identity_store_user_response

    @doc false
    defdelegate sandbox_delete_identity_store_user_response(user_id, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :delete_identity_store_user_response

    @doc false
    defdelegate sandbox_update_identity_store_user_response(user_id, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :update_identity_store_user_response

    @doc false
    defdelegate sandbox_describe_identity_store_user_response(user_id, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :describe_identity_store_user_response

    @doc false
    defdelegate sandbox_describe_identity_store_group_response(group_id, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :describe_identity_store_group_response

    @doc false
    defdelegate sandbox_list_identity_store_users_response(store_id, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :list_identity_store_users_response

    # Identity Store — Groups
    @doc false
    defdelegate sandbox_create_identity_store_group_response(name, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :create_identity_store_group_response

    @doc false
    defdelegate sandbox_delete_identity_store_group_response(group_id, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :delete_identity_store_group_response

    @doc false
    defdelegate sandbox_list_identity_store_groups_response(store_id, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :list_identity_store_groups_response

    @doc false
    defdelegate sandbox_create_group_membership_response(group_id, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :create_group_membership_response

    @doc false
    defdelegate sandbox_delete_group_membership_response(membership_id, opts),
      to: AWS.IdentityCenter.Sandbox,
      as: :delete_group_membership_response
  else
    defp sandbox_disabled?, do: true

    defp sandbox_list_instances_response(_), do: raise("sandbox not available")
    defp sandbox_create_permission_set_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_permission_set_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_permission_sets_response(_, _), do: raise("sandbox not available")

    defp sandbox_attach_managed_policy_to_permission_set_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_detach_managed_policy_from_permission_set_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_create_account_assignment_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_account_assignment_response(_, _), do: raise("sandbox not available")
    defp sandbox_create_identity_store_user_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_identity_store_user_response(_, _), do: raise("sandbox not available")
    defp sandbox_update_identity_store_user_response(_, _), do: raise("sandbox not available")
    defp sandbox_provision_permission_set_response(_, _), do: raise("sandbox not available")
    defp sandbox_describe_identity_store_user_response(_, _), do: raise("sandbox not available")
    defp sandbox_describe_identity_store_group_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_identity_store_users_response(_, _), do: raise("sandbox not available")
    defp sandbox_create_identity_store_group_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_identity_store_group_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_identity_store_groups_response(_, _), do: raise("sandbox not available")
    defp sandbox_create_group_membership_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_group_membership_response(_, _), do: raise("sandbox not available")
  end
end
