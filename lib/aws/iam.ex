defmodule AWS.IAM do
  @moduledoc """
  `AWS.IAM` provides an API for AWS Identity and Access Management (IAM).

  This module wraps IAM operations using `ExAws.Iam` (from `ex_aws_iam`) for users,
  access keys, and groups, and `ExAws.Operation.Query` directly for roles, policies,
  policy attachments, and group membership. It provides consistent error handling,
  response deserialization, and sandbox support.

  IAM is a global service — all requests are routed to `iam.amazonaws.com` regardless
  of `:region`.

  ## Shared Options

  The following options are available for most functions in this API:

    - `:region` - Accepted but unused for IAM (global service). Kept for API consistency.

    - `:iam` - A keyword list of options used to configure the ExAws IAM service.
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

      AWS.IAM.Sandbox.start_link()

  ### Usage

      setup do
        AWS.IAM.Sandbox.set_create_user_responses([
          {"alice", fn -> {:ok, %{user_name: "alice", arn: "arn:aws:iam::123:user/alice"}} end}
        ])
      end

      test "creates a user" do
        assert {:ok, %{user_name: "alice"}} =
                 AWS.IAM.create_user("alice", sandbox: [enabled: true, mode: :inline])
      end
  """

  import SweetXml, only: [xpath: 3, sigil_x: 2]
  alias AWS.{Config, Error}
  alias ExAws.Iam, as: API

  @custom_opts [:region, :iam, :sandbox]

  # ---------------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------------

  @doc """
  Creates an IAM user.

  ## Arguments

    * `username` - The user name (1–128 chars).
    * `opts` - Options including `:path`, `:permissions_boundary`, `:tags`,
      plus shared options.
  """
  @spec create_user(username :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_user(username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_user_response(username, opts)
    else
      do_create_user(username, opts)
    end
  end

  defp do_create_user(username, opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.create_user(username, api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn %{create_user_result: %{user: user}} -> {:ok, user} end)
  end

  @doc """
  Retrieves information about an IAM user.

  ## Arguments

    * `username` - The user name.
    * `opts` - Shared options.
  """
  @spec get_user(username :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_user(username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_user_response(username, opts)
    else
      do_get_user(username, opts)
    end
  end

  defp do_get_user(username, opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.get_user(username, api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn %{get_user_result: %{user: user}} -> {:ok, user} end)
  end

  @doc """
  Lists IAM users, optionally filtered by path prefix.

  ## Options

    * `:path_prefix` - Filter users whose path begins with this string.
    * `:max_items` - Maximum number of items to return.
    * `:marker` - Pagination marker from a previous call.
  """
  @spec list_users(opts :: keyword()) ::
          {:ok, %{users: list(map()), is_truncated: boolean(), marker: String.t() | nil}} |
          {:error, term()}
  def list_users(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_users_response(opts)
    else
      do_list_users(opts)
    end
  end

  defp do_list_users(opts) do
    {api_opts, config_opts} = split_opts(opts)

    api_opts =
      api_opts
      |> maybe_put_api(:path_prefix, opts[:path_prefix])
      |> maybe_put_api(:max_items, opts[:max_items])
      |> maybe_put_api(:marker, opts[:marker])

    API.list_users(api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn %{list_users_result: result} ->
      {:ok, %{users: result[:users] || [], is_truncated: result[:is_truncated], marker: result[:marker]}}
    end)
  end

  @doc """
  Deletes an IAM user.

  ## Arguments

    * `username` - The user name.
    * `opts` - Shared options.
  """
  @spec delete_user(username :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_user(username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_user_response(username, opts)
    else
      do_delete_user(username, opts)
    end
  end

  defp do_delete_user(username, opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.delete_user(username, api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Access Keys
  # ---------------------------------------------------------------------------

  @doc """
  Creates an access key pair for an IAM user.

  Returns the `secret_access_key` — this is the only time it is visible.

  ## Arguments

    * `username` - The user name.
    * `opts` - Shared options.
  """
  @spec create_access_key(username :: String.t(), opts :: keyword()) ::
          {:ok, %{access_key_id: String.t(), secret_access_key: String.t()}} | {:error, term()}
  def create_access_key(username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_access_key_response(username, opts)
    else
      do_create_access_key(username, opts)
    end
  end

  defp do_create_access_key(username, opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.create_access_key(username, api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn %{create_access_key_result: %{access_key: key}} ->
      {:ok, key}
    end)
  end

  @doc """
  Lists access keys for an IAM user.

  ## Arguments

    * `username` - The user name.
    * `opts` - Shared options.
  """
  @spec list_access_keys(username :: String.t(), opts :: keyword()) ::
          {:ok, %{access_keys: list(map())}} | {:error, term()}
  def list_access_keys(username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_access_keys_response(username, opts)
    else
      do_list_access_keys(username, opts)
    end
  end

  defp do_list_access_keys(username, opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.list_access_keys(Keyword.put(api_opts, :user_name, username))
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn %{list_access_keys_result: result} ->
      {:ok, %{access_keys: result[:access_key_metadata] || []}}
    end)
  end

  @doc """
  Deletes an access key.

  ## Arguments

    * `access_key_id` - The access key ID.
    * `username` - The user name.
    * `opts` - Shared options.
  """
  @spec delete_access_key(access_key_id :: String.t(), username :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_access_key(access_key_id, username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_access_key_response(access_key_id, username, opts)
    else
      do_delete_access_key(access_key_id, username, opts)
    end
  end

  defp do_delete_access_key(access_key_id, username, opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.delete_access_key(access_key_id, username, api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Groups
  # ---------------------------------------------------------------------------

  @doc """
  Creates an IAM group.

  ## Arguments

    * `name` - The group name.
    * `opts` - Options including `:path`, plus shared options.
  """
  @spec create_group(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_group(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_group_response(name, opts)
    else
      do_create_group(name, opts)
    end
  end

  defp do_create_group(name, opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.create_group(name, api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn %{create_group_result: %{group: group}} -> {:ok, group} end)
  end

  @doc """
  Lists IAM groups.

  ## Options

    * `:path_prefix` - Filter groups whose path begins with this string.
  """
  @spec list_groups(opts :: keyword()) ::
          {:ok, %{groups: list(map())}} | {:error, term()}
  def list_groups(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_groups_response(opts)
    else
      do_list_groups(opts)
    end
  end

  defp do_list_groups(opts) do
    {api_opts, config_opts} = split_opts(opts)

    api_opts = maybe_put_api(api_opts, :path_prefix, opts[:path_prefix])

    API.list_groups(api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn %{list_groups_result: result} ->
      {:ok, %{groups: result[:groups] || []}}
    end)
  end

  @doc """
  Deletes an IAM group.

  ## Arguments

    * `name` - The group name.
    * `opts` - Shared options.
  """
  @spec delete_group(name :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_group(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_group_response(name, opts)
    else
      do_delete_group(name, opts)
    end
  end

  defp do_delete_group(name, opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.delete_group(name, api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Group membership (raw Query — not covered by ex_aws_iam)
  # ---------------------------------------------------------------------------

  @doc """
  Adds an IAM user to a group.

  ## Arguments

    * `group_name` - The group name.
    * `username` - The user name.
    * `opts` - Shared options.
  """
  @spec add_user_to_group(group_name :: String.t(), username :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def add_user_to_group(group_name, username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_add_user_to_group_response(group_name, username, opts)
    else
      do_add_user_to_group(group_name, username, opts)
    end
  end

  defp do_add_user_to_group(group_name, username, opts) do
    build_operation("AddUserToGroup", %{"GroupName" => group_name, "UserName" => username})
    |> perform(opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Removes an IAM user from a group.

  ## Arguments

    * `group_name` - The group name.
    * `username` - The user name.
    * `opts` - Shared options.
  """
  @spec remove_user_from_group(group_name :: String.t(), username :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def remove_user_from_group(group_name, username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_remove_user_from_group_response(group_name, username, opts)
    else
      do_remove_user_from_group(group_name, username, opts)
    end
  end

  defp do_remove_user_from_group(group_name, username, opts) do
    build_operation("RemoveUserFromGroup", %{"GroupName" => group_name, "UserName" => username})
    |> perform(opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Roles (raw Query — not covered by ex_aws_iam)
  # ---------------------------------------------------------------------------

  @doc """
  Creates an IAM role with a trust policy.

  ## Arguments

    * `name` - The role name.
    * `trust_policy` - Elixir map defining the trust (assume-role) policy document.
      This is JSON-encoded before being sent to AWS.
    * `opts` - Options including `:path`, `:description`, `:max_session_duration`,
      plus shared options.
  """
  @spec create_role(name :: String.t(), trust_policy :: map(), opts :: keyword()) ::
          {:ok, %{role_name: String.t(), role_id: String.t(), arn: String.t()}} | {:error, term()}
  def create_role(name, trust_policy, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_role_response(name, opts)
    else
      do_create_role(name, trust_policy, opts)
    end
  end

  defp do_create_role(name, trust_policy, opts) do
    params =
      %{"RoleName" => name, "AssumeRolePolicyDocument" => Jason.encode!(trust_policy)}
      |> maybe_put("Path", opts[:path])
      |> maybe_put("Description", opts[:description])
      |> maybe_put("MaxSessionDuration", opts[:max_session_duration])

    build_operation("CreateRole", params)
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      {:ok, parse_role(body, ~x"//Role"e)}
    end)
  end

  @doc """
  Returns information about an IAM role.

  ## Arguments

    * `name` - The role name.
    * `opts` - Shared options.
  """
  @spec get_role(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_role(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_role_response(name, opts)
    else
      do_get_role(name, opts)
    end
  end

  defp do_get_role(name, opts) do
    build_operation("GetRole", %{"RoleName" => name})
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      {:ok, parse_role(body, ~x"//Role"e)}
    end)
  end

  @doc """
  Lists IAM roles.

  ## Options

    * `:path_prefix` - Filter roles whose path begins with this string.
    * `:max_items` - Maximum number of items.
    * `:marker` - Pagination marker.
  """
  @spec list_roles(opts :: keyword()) ::
          {:ok, %{roles: list(map())}} | {:error, term()}
  def list_roles(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_roles_response(opts)
    else
      do_list_roles(opts)
    end
  end

  defp do_list_roles(opts) do
    params =
      %{}
      |> maybe_put("PathPrefix", opts[:path_prefix])
      |> maybe_put("Marker", opts[:marker])
      |> maybe_put("MaxItems", opts[:max_items])

    build_operation("ListRoles", params)
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      roles = xpath(body, ~x"//Roles/member"l,
        role_name: ~x"./RoleName/text()"s,
        role_id: ~x"./RoleId/text()"s,
        arn: ~x"./Arn/text()"s,
        path: ~x"./Path/text()"s,
        create_date: ~x"./CreateDate/text()"s
      )
      {:ok, %{roles: roles}}
    end)
  end

  @doc """
  Deletes an IAM role.

  ## Arguments

    * `name` - The role name.
    * `opts` - Shared options.
  """
  @spec delete_role(name :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_role(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_role_response(name, opts)
    else
      do_delete_role(name, opts)
    end
  end

  defp do_delete_role(name, opts) do
    build_operation("DeleteRole", %{"RoleName" => name})
    |> perform(opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Policies (raw Query)
  # ---------------------------------------------------------------------------

  @doc """
  Creates a managed IAM policy.

  ## Arguments

    * `name` - The policy name.
    * `policy_document` - Elixir map defining the policy. JSON-encoded before sending.
    * `opts` - Options including `:path`, `:description`, plus shared options.
  """
  @spec create_policy(name :: String.t(), policy_document :: map(), opts :: keyword()) ::
          {:ok, %{policy_name: String.t(), policy_id: String.t(), arn: String.t()}} | {:error, term()}
  def create_policy(name, policy_document, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_policy_response(name, opts)
    else
      do_create_policy(name, policy_document, opts)
    end
  end

  defp do_create_policy(name, policy_document, opts) do
    params =
      %{"PolicyName" => name, "PolicyDocument" => Jason.encode!(policy_document)}
      |> maybe_put("Path", opts[:path])
      |> maybe_put("Description", opts[:description])

    build_operation("CreatePolicy", params)
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      {:ok, parse_policy(body, ~x"//Policy"e)}
    end)
  end

  @doc """
  Returns information about a managed IAM policy.

  ## Arguments

    * `policy_arn` - The policy ARN.
    * `opts` - Shared options.
  """
  @spec get_policy(policy_arn :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_policy(policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_policy_response(policy_arn, opts)
    else
      do_get_policy(policy_arn, opts)
    end
  end

  defp do_get_policy(policy_arn, opts) do
    build_operation("GetPolicy", %{"PolicyArn" => policy_arn})
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      {:ok, parse_policy(body, ~x"//Policy"e)}
    end)
  end

  @doc """
  Lists managed IAM policies.

  ## Options

    * `:scope` - `"All"`, `"AWS"`, or `"Local"` (default: `"Local"`).
    * `:only_attached` - If `true`, list only policies attached to an entity.
    * `:path_prefix` - Filter by path prefix.
    * `:max_items` - Maximum number of items.
    * `:marker` - Pagination marker.
  """
  @spec list_policies(opts :: keyword()) ::
          {:ok, %{policies: list(map())}} | {:error, term()}
  def list_policies(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_policies_response(opts)
    else
      do_list_policies(opts)
    end
  end

  defp do_list_policies(opts) do
    params =
      %{}
      |> maybe_put("Scope", opts[:scope])
      |> maybe_put("OnlyAttached", opts[:only_attached])
      |> maybe_put("PathPrefix", opts[:path_prefix])
      |> maybe_put("Marker", opts[:marker])
      |> maybe_put("MaxItems", opts[:max_items])

    build_operation("ListPolicies", params)
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      policies = xpath(body, ~x"//Policies/member"l,
        policy_name: ~x"./PolicyName/text()"s,
        policy_id: ~x"./PolicyId/text()"s,
        arn: ~x"./Arn/text()"s,
        path: ~x"./Path/text()"s,
        create_date: ~x"./CreateDate/text()"s,
        update_date: ~x"./UpdateDate/text()"s
      )
      {:ok, %{policies: policies}}
    end)
  end

  @doc """
  Deletes a managed IAM policy.

  ## Arguments

    * `policy_arn` - The policy ARN.
    * `opts` - Shared options.
  """
  @spec delete_policy(policy_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_policy(policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_policy_response(policy_arn, opts)
    else
      do_delete_policy(policy_arn, opts)
    end
  end

  defp do_delete_policy(policy_arn, opts) do
    build_operation("DeletePolicy", %{"PolicyArn" => policy_arn})
    |> perform(opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Policy attachments (raw Query)
  # ---------------------------------------------------------------------------

  @doc """
  Attaches a managed policy to a role.
  """
  @spec attach_role_policy(role_name :: String.t(), policy_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def attach_role_policy(role_name, policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_attach_role_policy_response(role_name, policy_arn, opts)
    else
      do_attach_role_policy(role_name, policy_arn, opts)
    end
  end

  defp do_attach_role_policy(role_name, policy_arn, opts) do
    build_operation("AttachRolePolicy", %{"RoleName" => role_name, "PolicyArn" => policy_arn})
    |> perform(opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Detaches a managed policy from a role.
  """
  @spec detach_role_policy(role_name :: String.t(), policy_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def detach_role_policy(role_name, policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_detach_role_policy_response(role_name, policy_arn, opts)
    else
      do_detach_role_policy(role_name, policy_arn, opts)
    end
  end

  defp do_detach_role_policy(role_name, policy_arn, opts) do
    build_operation("DetachRolePolicy", %{"RoleName" => role_name, "PolicyArn" => policy_arn})
    |> perform(opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Lists managed policies attached to a role.
  """
  @spec list_attached_role_policies(role_name :: String.t(), opts :: keyword()) ::
          {:ok, %{policies: list(map())}} | {:error, term()}
  def list_attached_role_policies(role_name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_attached_role_policies_response(role_name, opts)
    else
      do_list_attached_role_policies(role_name, opts)
    end
  end

  defp do_list_attached_role_policies(role_name, opts) do
    build_operation("ListAttachedRolePolicies", %{"RoleName" => role_name})
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      policies = xpath(body, ~x"//AttachedPolicies/member"l,
        policy_name: ~x"./PolicyName/text()"s,
        policy_arn: ~x"./PolicyArn/text()"s
      )
      {:ok, %{policies: policies}}
    end)
  end

  @doc """
  Attaches a managed policy to a user.
  """
  @spec attach_user_policy(username :: String.t(), policy_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def attach_user_policy(username, policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_attach_user_policy_response(username, policy_arn, opts)
    else
      do_attach_user_policy(username, policy_arn, opts)
    end
  end

  defp do_attach_user_policy(username, policy_arn, opts) do
    build_operation("AttachUserPolicy", %{"UserName" => username, "PolicyArn" => policy_arn})
    |> perform(opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Detaches a managed policy from a user.
  """
  @spec detach_user_policy(username :: String.t(), policy_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def detach_user_policy(username, policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_detach_user_policy_response(username, policy_arn, opts)
    else
      do_detach_user_policy(username, policy_arn, opts)
    end
  end

  defp do_detach_user_policy(username, policy_arn, opts) do
    build_operation("DetachUserPolicy", %{"UserName" => username, "PolicyArn" => policy_arn})
    |> perform(opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Attaches a managed policy to a group.
  """
  @spec attach_group_policy(group_name :: String.t(), policy_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def attach_group_policy(group_name, policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_attach_group_policy_response(group_name, policy_arn, opts)
    else
      do_attach_group_policy(group_name, policy_arn, opts)
    end
  end

  defp do_attach_group_policy(group_name, policy_arn, opts) do
    build_operation("AttachGroupPolicy", %{"GroupName" => group_name, "PolicyArn" => policy_arn})
    |> perform(opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Detaches a managed policy from a group.
  """
  @spec detach_group_policy(group_name :: String.t(), policy_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def detach_group_policy(group_name, policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_detach_group_policy_response(group_name, policy_arn, opts)
    else
      do_detach_group_policy(group_name, policy_arn, opts)
    end
  end

  defp do_detach_group_policy(group_name, policy_arn, opts) do
    build_operation("DetachGroupPolicy", %{"GroupName" => group_name, "PolicyArn" => policy_arn})
    |> perform(opts)
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
    defdelegate sandbox_disabled?, to: AWS.IAM.Sandbox

    # Users
    @doc false
    defdelegate sandbox_create_user_response(name, opts), to: AWS.IAM.Sandbox, as: :create_user_response
    @doc false
    defdelegate sandbox_get_user_response(name, opts), to: AWS.IAM.Sandbox, as: :get_user_response
    @doc false
    defdelegate sandbox_list_users_response(opts), to: AWS.IAM.Sandbox, as: :list_users_response
    @doc false
    defdelegate sandbox_delete_user_response(name, opts), to: AWS.IAM.Sandbox, as: :delete_user_response

    # Access Keys
    @doc false
    defdelegate sandbox_create_access_key_response(username, opts), to: AWS.IAM.Sandbox, as: :create_access_key_response
    @doc false
    defdelegate sandbox_list_access_keys_response(username, opts), to: AWS.IAM.Sandbox, as: :list_access_keys_response
    @doc false
    defdelegate sandbox_delete_access_key_response(key_id, username, opts), to: AWS.IAM.Sandbox, as: :delete_access_key_response

    # Groups
    @doc false
    defdelegate sandbox_create_group_response(name, opts), to: AWS.IAM.Sandbox, as: :create_group_response
    @doc false
    defdelegate sandbox_list_groups_response(opts), to: AWS.IAM.Sandbox, as: :list_groups_response
    @doc false
    defdelegate sandbox_delete_group_response(name, opts), to: AWS.IAM.Sandbox, as: :delete_group_response

    # Group membership
    @doc false
    defdelegate sandbox_add_user_to_group_response(group, user, opts), to: AWS.IAM.Sandbox, as: :add_user_to_group_response
    @doc false
    defdelegate sandbox_remove_user_from_group_response(group, user, opts), to: AWS.IAM.Sandbox, as: :remove_user_from_group_response

    # Roles
    @doc false
    defdelegate sandbox_create_role_response(name, opts), to: AWS.IAM.Sandbox, as: :create_role_response
    @doc false
    defdelegate sandbox_get_role_response(name, opts), to: AWS.IAM.Sandbox, as: :get_role_response
    @doc false
    defdelegate sandbox_list_roles_response(opts), to: AWS.IAM.Sandbox, as: :list_roles_response
    @doc false
    defdelegate sandbox_delete_role_response(name, opts), to: AWS.IAM.Sandbox, as: :delete_role_response

    # Policies
    @doc false
    defdelegate sandbox_create_policy_response(name, opts), to: AWS.IAM.Sandbox, as: :create_policy_response
    @doc false
    defdelegate sandbox_get_policy_response(arn, opts), to: AWS.IAM.Sandbox, as: :get_policy_response
    @doc false
    defdelegate sandbox_list_policies_response(opts), to: AWS.IAM.Sandbox, as: :list_policies_response
    @doc false
    defdelegate sandbox_delete_policy_response(arn, opts), to: AWS.IAM.Sandbox, as: :delete_policy_response

    # Attachments
    @doc false
    defdelegate sandbox_attach_role_policy_response(role, arn, opts), to: AWS.IAM.Sandbox, as: :attach_role_policy_response
    @doc false
    defdelegate sandbox_detach_role_policy_response(role, arn, opts), to: AWS.IAM.Sandbox, as: :detach_role_policy_response
    @doc false
    defdelegate sandbox_list_attached_role_policies_response(role, opts), to: AWS.IAM.Sandbox, as: :list_attached_role_policies_response
    @doc false
    defdelegate sandbox_attach_user_policy_response(user, arn, opts), to: AWS.IAM.Sandbox, as: :attach_user_policy_response
    @doc false
    defdelegate sandbox_detach_user_policy_response(user, arn, opts), to: AWS.IAM.Sandbox, as: :detach_user_policy_response
    @doc false
    defdelegate sandbox_attach_group_policy_response(group, arn, opts), to: AWS.IAM.Sandbox, as: :attach_group_policy_response
    @doc false
    defdelegate sandbox_detach_group_policy_response(group, arn, opts), to: AWS.IAM.Sandbox, as: :detach_group_policy_response
  else
    defp sandbox_disabled?, do: true

    # Users
    defp sandbox_create_user_response(_, _), do: raise("sandbox not available")
    defp sandbox_get_user_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_users_response(_), do: raise("sandbox not available")
    defp sandbox_delete_user_response(_, _), do: raise("sandbox not available")

    # Access Keys
    defp sandbox_create_access_key_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_access_keys_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_access_key_response(_, _, _), do: raise("sandbox not available")

    # Groups
    defp sandbox_create_group_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_groups_response(_), do: raise("sandbox not available")
    defp sandbox_delete_group_response(_, _), do: raise("sandbox not available")

    # Group membership
    defp sandbox_add_user_to_group_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_remove_user_from_group_response(_, _, _), do: raise("sandbox not available")

    # Roles
    defp sandbox_create_role_response(_, _), do: raise("sandbox not available")
    defp sandbox_get_role_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_roles_response(_), do: raise("sandbox not available")
    defp sandbox_delete_role_response(_, _), do: raise("sandbox not available")

    # Policies
    defp sandbox_create_policy_response(_, _), do: raise("sandbox not available")
    defp sandbox_get_policy_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_policies_response(_), do: raise("sandbox not available")
    defp sandbox_delete_policy_response(_, _), do: raise("sandbox not available")

    # Attachments
    defp sandbox_attach_role_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_detach_role_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_list_attached_role_policies_response(_, _), do: raise("sandbox not available")
    defp sandbox_attach_user_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_detach_user_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_attach_group_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_detach_group_policy_response(_, _, _), do: raise("sandbox not available")
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp perform(operation, opts) do
    ExAws.Operation.perform(operation, iam_config(opts))
  end

  defp iam_config(opts) do
    {iam_opts, opts} = Keyword.pop(opts, :iam, [])
    {sandbox_opts, _opts} = Keyword.pop(opts, :sandbox, [])

    overrides =
      iam_opts
      |> Keyword.put_new(:host, "iam.amazonaws.com")
      |> configure_endpoint(sandbox_opts)

    ExAws.Config.new(:iam, overrides)
  end

  defp configure_endpoint(iam_opts, sandbox_opts) do
    sandbox_enabled = sandbox_opts[:enabled] || Config.sandbox_enabled?()
    sandbox_mode = sandbox_opts[:mode] || Config.sandbox_mode()

    if sandbox_enabled and sandbox_mode === :local do
      iam_opts
      |> Keyword.put(:scheme, Config.sandbox_scheme())
      |> Keyword.put(:host, Config.sandbox_host())
      |> Keyword.put(:port, Config.sandbox_port())
      |> Keyword.put_new(:access_key_id, "test")
      |> Keyword.put_new(:secret_access_key, "test")
    else
      maybe_put_credentials(iam_opts)
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

  defp build_operation(action, params) do
    %ExAws.Operation.Query{
      service: :iam,
      action: action,
      params: Map.merge(%{"Action" => action, "Version" => "2010-05-08"}, params)
    }
  end

  defp split_opts(opts) do
    {Keyword.drop(opts, @custom_opts), Keyword.take(opts, @custom_opts)}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_api(opts, _key, nil), do: opts
  defp maybe_put_api(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_role(body, path) do
    xpath(body, path,
      role_name: ~x"./RoleName/text()"s,
      role_id: ~x"./RoleId/text()"s,
      arn: ~x"./Arn/text()"s,
      path: ~x"./Path/text()"s,
      create_date: ~x"./CreateDate/text()"s
    )
  end

  defp parse_policy(body, path) do
    xpath(body, path,
      policy_name: ~x"./PolicyName/text()"s,
      policy_id: ~x"./PolicyId/text()"s,
      arn: ~x"./Arn/text()"s,
      path: ~x"./Path/text()"s,
      create_date: ~x"./CreateDate/text()"s,
      update_date: ~x"./UpdateDate/text()"s,
      default_version_id: ~x"./DefaultVersionId/text()"s
    )
  end
end
