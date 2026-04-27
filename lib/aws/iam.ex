defmodule AWS.IAM do
  @moduledoc """
  `AWS.IAM` provides an API for AWS Identity and Access Management (IAM).

  This module calls the AWS IAM Query API directly via `AWS.HTTP` and
  `AWS.Signer` (through `AWS.IAM.Client`).

  IAM's public API is XML-only at the AWS wire level. The service model
  (`botocore/data/iam/2010-05-08/service-2.json`) declares
  `metadata.protocols = ["query"]`, and AWS does not expose a JSON IAM
  endpoint. The form-urlencoded request / XML response handling here
  (XPath extraction via `SweetXml`) is a consequence of AWS's protocol
  choice, not a library decision.

  IAM is a global service; all requests are routed to `iam.amazonaws.com`
  regardless of `:region` (SigV4 still needs a region, so `us-east-1` is
  used by convention).

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

  IAM is a global service; requests always go to `iam.amazonaws.com`. The
  `:region` opt is used only for SigV4 signing and defaults to `"us-east-1"`.

  The following options are also available:

    - `:iam` - A keyword list of IAM endpoint overrides. Supported keys:
      `:scheme`, `:host`, `:port`. Credentials are not read from this
      sub-list; use the top-level keys above.

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

  import SweetXml, only: [xpath: 2, xpath: 3, sigil_x: 2]
  alias AWS.{Client, Config, Error}
  alias AWS.IAM.Operation

  @service "iam"
  @content_type "application/x-www-form-urlencoded"
  @api_version "2010-05-08"
  @default_region "us-east-1"
  @default_host "iam.amazonaws.com"

  @override_keys [:headers, :body, :http, :url]

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
    params =
      %{"UserName" => username}
      |> maybe_put("Path", opts[:path])
      |> maybe_put("PermissionsBoundary", opts[:permissions_boundary])

    "CreateUser"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      {:ok, parse_user(body, ~x"//CreateUserResult/User"e)}
    end)
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
    "GetUser"
    |> perform(%{"UserName" => username}, opts)
    |> deserialize_response(opts, fn body ->
      {:ok, parse_user(body, ~x"//GetUserResult/User"e)}
    end)
  end

  @doc """
  Lists IAM users, optionally filtered by path prefix.

  ## Options

    * `:path_prefix` - Filter users whose path begins with this string.
    * `:max_items` - Maximum number of items to return.
    * `:marker` - Pagination marker from a previous call.
  """
  @spec list_users(opts :: keyword()) ::
          {:ok, %{users: list(map()), is_truncated: boolean(), marker: String.t() | nil}}
          | {:error, term()}
  def list_users(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_users_response(opts)
    else
      do_list_users(opts)
    end
  end

  defp do_list_users(opts) do
    params =
      %{}
      |> maybe_put("PathPrefix", opts[:path_prefix])
      |> maybe_put("MaxItems", opts[:max_items])
      |> maybe_put("Marker", opts[:marker])

    "ListUsers"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      result =
        xpath(body, ~x"//ListUsersResult"e,
          users: [
            ~x"./Users/member"l,
            user_name: ~x"./UserName/text()"s,
            user_id: ~x"./UserId/text()"s,
            arn: ~x"./Arn/text()"s,
            path: ~x"./Path/text()"s,
            create_date: ~x"./CreateDate/text()"s
          ],
          is_truncated: ~x"./IsTruncated/text()"s,
          marker: ~x"./Marker/text()"s
        )

      {:ok,
       %{
         users: result.users,
         is_truncated: result.is_truncated === "true",
         marker: if(result.marker === "", do: nil, else: result.marker)
       }}
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
    "DeleteUser"
    |> perform(%{"UserName" => username}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
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
    "CreateAccessKey"
    |> perform(%{"UserName" => username}, opts)
    |> deserialize_response(opts, fn body ->
      {:ok, parse_access_key(body, ~x"//CreateAccessKeyResult/AccessKey"e)}
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
    "ListAccessKeys"
    |> perform(%{"UserName" => username}, opts)
    |> deserialize_response(opts, fn body ->
      access_keys =
        xpath(body, ~x"//AccessKeyMetadata/member"l,
          access_key_id: ~x"./AccessKeyId/text()"s,
          user_name: ~x"./UserName/text()"s,
          status: ~x"./Status/text()"s,
          create_date: ~x"./CreateDate/text()"s
        )

      {:ok, %{access_keys: access_keys}}
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
    "DeleteAccessKey"
    |> perform(%{"AccessKeyId" => access_key_id, "UserName" => username}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
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
    params = maybe_put(%{"GroupName" => name}, "Path", opts[:path])

    "CreateGroup"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      {:ok, parse_group(body, ~x"//CreateGroupResult/Group"e)}
    end)
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
    params =
      %{}
      |> maybe_put("PathPrefix", opts[:path_prefix])
      |> maybe_put("MaxItems", opts[:max_items])
      |> maybe_put("Marker", opts[:marker])

    "ListGroups"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      groups =
        xpath(body, ~x"//Groups/member"l,
          group_name: ~x"./GroupName/text()"s,
          group_id: ~x"./GroupId/text()"s,
          arn: ~x"./Arn/text()"s,
          path: ~x"./Path/text()"s,
          create_date: ~x"./CreateDate/text()"s
        )

      {:ok, %{groups: groups}}
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
    "DeleteGroup"
    |> perform(%{"GroupName" => name}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Group membership
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
    "AddUserToGroup"
    |> perform(%{"GroupName" => group_name, "UserName" => username}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Removes an IAM user from a group.

  ## Arguments

    * `group_name` - The group name.
    * `username` - The user name.
    * `opts` - Shared options.
  """
  @spec remove_user_from_group(
          group_name :: String.t(),
          username :: String.t(),
          opts :: keyword()
        ) ::
          {:ok, %{}} | {:error, term()}
  def remove_user_from_group(group_name, username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_remove_user_from_group_response(group_name, username, opts)
    else
      do_remove_user_from_group(group_name, username, opts)
    end
  end

  defp do_remove_user_from_group(group_name, username, opts) do
    "RemoveUserFromGroup"
    |> perform(%{"GroupName" => group_name, "UserName" => username}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Roles
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
      %{
        "RoleName" => name,
        "AssumeRolePolicyDocument" => trust_policy |> :json.encode() |> IO.iodata_to_binary()
      }
      |> maybe_put("Path", opts[:path])
      |> maybe_put("Description", opts[:description])
      |> maybe_put("MaxSessionDuration", opts[:max_session_duration])

    "CreateRole"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
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
    "GetRole"
    |> perform(%{"RoleName" => name}, opts)
    |> deserialize_response(opts, fn body ->
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

    "ListRoles"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      roles =
        xpath(body, ~x"//Roles/member"l,
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
    "DeleteRole"
    |> perform(%{"RoleName" => name}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Updates the trust policy (assume role policy document) of an IAM role.

  ## Arguments

    * `role_name` - The role name.
    * `policy_document` - Elixir map of the trust policy. JSON-encoded before sending.
    * `opts` - Shared options.
  """
  @spec update_assume_role_policy(
          role_name :: String.t(),
          policy_document :: map(),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def update_assume_role_policy(role_name, policy_document, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_update_assume_role_policy_response(role_name, opts)
    else
      do_update_assume_role_policy(role_name, policy_document, opts)
    end
  end

  defp do_update_assume_role_policy(role_name, policy_document, opts) do
    params = %{
      "RoleName" => role_name,
      "PolicyDocument" => policy_document |> :json.encode() |> IO.iodata_to_binary()
    }

    "UpdateAssumeRolePolicy"
    |> perform(params, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Inline role policies
  # ---------------------------------------------------------------------------

  @doc """
  Adds or updates an inline policy document embedded in an IAM role.

  ## Arguments

    * `role_name` - The role name.
    * `policy_name` - The inline policy name.
    * `document` - Elixir map of the policy. JSON-encoded before sending.
    * `opts` - Shared options.
  """
  @spec put_role_policy(
          role_name :: String.t(),
          policy_name :: String.t(),
          document :: map(),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def put_role_policy(role_name, policy_name, document, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_role_policy_response(role_name, policy_name, opts)
    else
      do_put_role_policy(role_name, policy_name, document, opts)
    end
  end

  defp do_put_role_policy(role_name, policy_name, document, opts) do
    params = %{
      "RoleName" => role_name,
      "PolicyName" => policy_name,
      "PolicyDocument" => document |> :json.encode() |> IO.iodata_to_binary()
    }

    "PutRolePolicy"
    |> perform(params, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Returns an inline policy document embedded in an IAM role.

  The `<PolicyDocument>` element returned by AWS is URL-encoded JSON; this
  function URI-decodes and JSON-decodes it so `:policy_document` is an
  Elixir map.

  ## Arguments

    * `role_name` - The role name.
    * `policy_name` - The inline policy name.
    * `opts` - Shared options.
  """
  @spec get_role_policy(
          role_name :: String.t(),
          policy_name :: String.t(),
          opts :: keyword()
        ) ::
          {:ok, %{role_name: String.t(), policy_name: String.t(), policy_document: map()}}
          | {:error, term()}
  def get_role_policy(role_name, policy_name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_role_policy_response(role_name, policy_name, opts)
    else
      do_get_role_policy(role_name, policy_name, opts)
    end
  end

  defp do_get_role_policy(role_name, policy_name, opts) do
    "GetRolePolicy"
    |> perform(%{"RoleName" => role_name, "PolicyName" => policy_name}, opts)
    |> deserialize_response(opts, fn body ->
      fields =
        xpath(body, ~x"//GetRolePolicyResult"e,
          role_name: ~x"./RoleName/text()"s,
          policy_name: ~x"./PolicyName/text()"s,
          policy_document: ~x"./PolicyDocument/text()"s
        )

      document = fields.policy_document |> URI.decode() |> :json.decode()

      {:ok,
       %{
         role_name: fields.role_name,
         policy_name: fields.policy_name,
         policy_document: document
       }}
    end)
  end

  @doc """
  Deletes an inline policy from an IAM role.

  ## Arguments

    * `role_name` - The role name.
    * `policy_name` - The inline policy name.
    * `opts` - Shared options.
  """
  @spec delete_role_policy(
          role_name :: String.t(),
          policy_name :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def delete_role_policy(role_name, policy_name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_role_policy_response(role_name, policy_name, opts)
    else
      do_delete_role_policy(role_name, policy_name, opts)
    end
  end

  defp do_delete_role_policy(role_name, policy_name, opts) do
    "DeleteRolePolicy"
    |> perform(%{"RoleName" => role_name, "PolicyName" => policy_name}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Lists the names of inline policies embedded in an IAM role.

  ## Arguments

    * `role_name` - The role name.
    * `opts` - Options including `:marker`, `:max_items`, plus shared options.

  Returns `{:ok, %{policy_names: [String.t()], is_truncated: boolean(), marker: String.t() | nil}}`.
  """
  @spec list_role_policies(role_name :: String.t(), opts :: keyword()) ::
          {:ok,
           %{
             policy_names: list(String.t()),
             is_truncated: boolean(),
             marker: String.t() | nil
           }}
          | {:error, term()}
  def list_role_policies(role_name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_role_policies_response(role_name, opts)
    else
      do_list_role_policies(role_name, opts)
    end
  end

  defp do_list_role_policies(role_name, opts) do
    params =
      %{"RoleName" => role_name}
      |> maybe_put("Marker", opts[:marker])
      |> maybe_put("MaxItems", opts[:max_items])

    "ListRolePolicies"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      policy_names = xpath(body, ~x"//PolicyNames/member/text()"ls)
      is_truncated = xpath(body, ~x"//IsTruncated/text()"s) === "true"
      marker = xpath(body, ~x"//Marker/text()"s)

      {:ok,
       %{
         policy_names: policy_names,
         is_truncated: is_truncated,
         marker: if(marker === "", do: nil, else: marker)
       }}
    end)
  end

  # ---------------------------------------------------------------------------
  # Policies
  # ---------------------------------------------------------------------------

  @doc """
  Creates a managed IAM policy.

  ## Arguments

    * `name` - The policy name.
    * `policy_document` - Elixir map defining the policy. JSON-encoded before sending.
    * `opts` - Options including `:path`, `:description`, plus shared options.
  """
  @spec create_policy(name :: String.t(), policy_document :: map(), opts :: keyword()) ::
          {:ok, %{policy_name: String.t(), policy_id: String.t(), arn: String.t()}}
          | {:error, term()}
  def create_policy(name, policy_document, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_policy_response(name, opts)
    else
      do_create_policy(name, policy_document, opts)
    end
  end

  defp do_create_policy(name, policy_document, opts) do
    params =
      %{
        "PolicyName" => name,
        "PolicyDocument" => policy_document |> :json.encode() |> IO.iodata_to_binary()
      }
      |> maybe_put("Path", opts[:path])
      |> maybe_put("Description", opts[:description])

    "CreatePolicy"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
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
    "GetPolicy"
    |> perform(%{"PolicyArn" => policy_arn}, opts)
    |> deserialize_response(opts, fn body ->
      {:ok, parse_policy(body, ~x"//Policy"e)}
    end)
  end

  @doc """
  Returns a specific version of a managed IAM policy, including the policy document.

  The `<Document>` element returned by AWS is URL-encoded JSON; this function
  URI-decodes and JSON-decodes it so `:document` is an Elixir map.

  ## Arguments

    * `policy_arn` - The policy ARN.
    * `version_id` - The version ID (e.g. `"v1"`).
    * `opts` - Shared options.
  """
  @spec get_policy_version(policy_arn :: String.t(), version_id :: String.t(), opts :: keyword()) ::
          {:ok,
           %{
             document: map(),
             version_id: String.t(),
             is_default_version: boolean(),
             create_date: String.t()
           }}
          | {:error, term()}
  def get_policy_version(policy_arn, version_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_policy_version_response(policy_arn, version_id, opts)
    else
      do_get_policy_version(policy_arn, version_id, opts)
    end
  end

  defp do_get_policy_version(policy_arn, version_id, opts) do
    "GetPolicyVersion"
    |> perform(%{"PolicyArn" => policy_arn, "VersionId" => version_id}, opts)
    |> deserialize_response(opts, fn body ->
      fields =
        xpath(body, ~x"//GetPolicyVersionResult/PolicyVersion"e,
          document: ~x"./Document/text()"s,
          version_id: ~x"./VersionId/text()"s,
          is_default_version: ~x"./IsDefaultVersion/text()"s,
          create_date: ~x"./CreateDate/text()"s
        )

      document =
        fields.document
        |> URI.decode()
        |> :json.decode()

      {:ok,
       %{
         document: document,
         version_id: fields.version_id,
         is_default_version: fields.is_default_version === "true",
         create_date: fields.create_date
       }}
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

    "ListPolicies"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      policies =
        xpath(body, ~x"//Policies/member"l,
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
    "DeletePolicy"
    |> perform(%{"PolicyArn" => policy_arn}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Creates a new version of a managed IAM policy.

  ## Arguments

    * `policy_arn` - The policy ARN.
    * `document` - Elixir map of the policy document. JSON-encoded before sending.
    * `opts` - Options including `:set_as_default` (boolean), plus shared options.

  Returns `{:ok, %{policy_version: %{version_id, is_default_version, create_date}}}`.
  """
  @spec create_policy_version(
          policy_arn :: String.t(),
          document :: map(),
          opts :: keyword()
        ) :: {:ok, %{policy_version: map()}} | {:error, term()}
  def create_policy_version(policy_arn, document, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_policy_version_response(policy_arn, opts)
    else
      do_create_policy_version(policy_arn, document, opts)
    end
  end

  defp do_create_policy_version(policy_arn, document, opts) do
    params =
      %{
        "PolicyArn" => policy_arn,
        "PolicyDocument" => document |> :json.encode() |> IO.iodata_to_binary()
      }
      |> maybe_put("SetAsDefault", opts[:set_as_default])

    "CreatePolicyVersion"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      fields =
        xpath(body, ~x"//PolicyVersion"e,
          version_id: ~x"./VersionId/text()"s,
          is_default_version: ~x"./IsDefaultVersion/text()"s,
          create_date: ~x"./CreateDate/text()"s
        )

      {:ok,
       %{
         policy_version: %{
           version_id: fields.version_id,
           is_default_version: fields.is_default_version === "true",
           create_date: fields.create_date
         }
       }}
    end)
  end

  @doc """
  Sets a specific version of a managed policy as the default version.

  ## Arguments

    * `policy_arn` - The policy ARN.
    * `version_id` - The version ID to promote (e.g. `"v3"`).
    * `opts` - Shared options.
  """
  @spec set_default_policy_version(
          policy_arn :: String.t(),
          version_id :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def set_default_policy_version(policy_arn, version_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_set_default_policy_version_response(policy_arn, version_id, opts)
    else
      do_set_default_policy_version(policy_arn, version_id, opts)
    end
  end

  defp do_set_default_policy_version(policy_arn, version_id, opts) do
    "SetDefaultPolicyVersion"
    |> perform(%{"PolicyArn" => policy_arn, "VersionId" => version_id}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Deletes a version of a managed policy. The default version cannot be deleted.

  ## Arguments

    * `policy_arn` - The policy ARN.
    * `version_id` - The version ID to delete.
    * `opts` - Shared options.
  """
  @spec delete_policy_version(
          policy_arn :: String.t(),
          version_id :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def delete_policy_version(policy_arn, version_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_policy_version_response(policy_arn, version_id, opts)
    else
      do_delete_policy_version(policy_arn, version_id, opts)
    end
  end

  defp do_delete_policy_version(policy_arn, version_id, opts) do
    "DeletePolicyVersion"
    |> perform(%{"PolicyArn" => policy_arn, "VersionId" => version_id}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Lists the versions of a managed policy.

  ## Arguments

    * `policy_arn` - The policy ARN.
    * `opts` - Options including `:marker`, `:max_items`, plus shared options.

  Returns `{:ok, %{versions: [map()], is_truncated: boolean(), marker: String.t() | nil}}`
  where each version has `:version_id`, `:is_default_version`, `:create_date`.
  """
  @spec list_policy_versions(policy_arn :: String.t(), opts :: keyword()) ::
          {:ok,
           %{
             versions: list(map()),
             is_truncated: boolean(),
             marker: String.t() | nil
           }}
          | {:error, term()}
  def list_policy_versions(policy_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_policy_versions_response(policy_arn, opts)
    else
      do_list_policy_versions(policy_arn, opts)
    end
  end

  defp do_list_policy_versions(policy_arn, opts) do
    params =
      %{"PolicyArn" => policy_arn}
      |> maybe_put("Marker", opts[:marker])
      |> maybe_put("MaxItems", opts[:max_items])

    "ListPolicyVersions"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      versions =
        xpath(body, ~x"//Versions/member"l,
          version_id: ~x"./VersionId/text()"s,
          is_default_version: ~x"./IsDefaultVersion/text()"s,
          create_date: ~x"./CreateDate/text()"s
        )
        |> Enum.map(fn v -> %{v | is_default_version: v.is_default_version === "true"} end)

      is_truncated = xpath(body, ~x"//IsTruncated/text()"s) === "true"
      marker = xpath(body, ~x"//Marker/text()"s)

      {:ok,
       %{
         versions: versions,
         is_truncated: is_truncated,
         marker: if(marker === "", do: nil, else: marker)
       }}
    end)
  end

  # ---------------------------------------------------------------------------
  # Policy attachments
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
    "AttachRolePolicy"
    |> perform(%{"RoleName" => role_name, "PolicyArn" => policy_arn}, opts)
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
    "DetachRolePolicy"
    |> perform(%{"RoleName" => role_name, "PolicyArn" => policy_arn}, opts)
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
    "ListAttachedRolePolicies"
    |> perform(%{"RoleName" => role_name}, opts)
    |> deserialize_response(opts, fn body ->
      policies =
        xpath(body, ~x"//AttachedPolicies/member"l,
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
    "AttachUserPolicy"
    |> perform(%{"UserName" => username, "PolicyArn" => policy_arn}, opts)
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
    "DetachUserPolicy"
    |> perform(%{"UserName" => username, "PolicyArn" => policy_arn}, opts)
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
    "AttachGroupPolicy"
    |> perform(%{"GroupName" => group_name, "PolicyArn" => policy_arn}, opts)
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
    "DetachGroupPolicy"
    |> perform(%{"GroupName" => group_name, "PolicyArn" => policy_arn}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # MFA Devices
  # ---------------------------------------------------------------------------

  @doc """
  Lists the MFA devices for an IAM user.

  Note: IAM Identity Center users (from the identity store) are distinct from
  IAM users. This action only returns devices for users that exist as IAM users
  (including those created via federation or linked to Identity Center).

  ## Arguments

    * `username` - The IAM user name.
    * `opts` - Options including `:max_items`, `:marker`, plus shared options.
  """
  @spec list_mfa_devices(username :: String.t(), opts :: keyword()) ::
          {:ok,
           %{
             mfa_devices: list(map()),
             is_truncated: boolean(),
             marker: String.t() | nil
           }}
          | {:error, term()}
  def list_mfa_devices(username, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_mfa_devices_response(username, opts)
    else
      do_list_mfa_devices(username, opts)
    end
  end

  defp do_list_mfa_devices(username, opts) do
    params =
      %{"UserName" => username}
      |> maybe_put("Marker", opts[:marker])
      |> maybe_put("MaxItems", opts[:max_items])

    "ListMFADevices"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      %{devices: devices, is_truncated: is_truncated, marker: marker} =
        xpath(body, ~x"//ListMFADevicesResult"e,
          devices: [
            ~x"./MFADevices/member"l,
            user_name: ~x"./UserName/text()"s,
            serial_number: ~x"./SerialNumber/text()"s,
            enable_date: ~x"./EnableDate/text()"s
          ],
          is_truncated: ~x"./IsTruncated/text()"s,
          marker: ~x"./Marker/text()"s
        )

      {:ok,
       %{
         mfa_devices: devices,
         is_truncated: is_truncated === "true",
         marker: if(marker === "", do: nil, else: marker)
       }}
    end)
  end

  # ---------------------------------------------------------------------------
  # OIDC Providers
  # ---------------------------------------------------------------------------

  @doc """
  Creates an OpenID Connect (OIDC) identity provider in IAM.

  ## Arguments

    * `url` - The OIDC provider URL.
    * `client_id_list` - List of client IDs (audiences).
    * `opts` - Options including `:thumbprint_list` (required by AWS — list of
      server certificate thumbprints), plus shared options.
  """
  @spec create_open_id_connect_provider(
          url :: String.t(),
          client_id_list :: list(String.t()),
          opts :: keyword()
        ) :: {:ok, %{open_id_connect_provider_arn: String.t()}} | {:error, term()}
  def create_open_id_connect_provider(url, client_id_list, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_open_id_connect_provider_response(url, opts)
    else
      do_create_open_id_connect_provider(url, client_id_list, opts)
    end
  end

  defp do_create_open_id_connect_provider(url, client_id_list, opts) do
    params =
      %{"Url" => url}
      |> put_member_list("ClientIDList", client_id_list)
      |> put_member_list("ThumbprintList", opts[:thumbprint_list] || [])

    "CreateOpenIDConnectProvider"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      arn = xpath(body, ~x"//OpenIDConnectProviderArn/text()"s)
      {:ok, %{open_id_connect_provider_arn: arn}}
    end)
  end

  @doc """
  Returns information about an OIDC provider.

  ## Arguments

    * `provider_arn` - The OIDC provider ARN.
    * `opts` - Shared options.
  """
  @spec get_open_id_connect_provider(provider_arn :: String.t(), opts :: keyword()) ::
          {:ok,
           %{
             url: String.t(),
             client_id_list: list(String.t()),
             thumbprint_list: list(String.t()),
             create_date: String.t()
           }}
          | {:error, term()}
  def get_open_id_connect_provider(provider_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_open_id_connect_provider_response(provider_arn, opts)
    else
      do_get_open_id_connect_provider(provider_arn, opts)
    end
  end

  defp do_get_open_id_connect_provider(provider_arn, opts) do
    "GetOpenIDConnectProvider"
    |> perform(%{"OpenIDConnectProviderArn" => provider_arn}, opts)
    |> deserialize_response(opts, fn body ->
      fields =
        xpath(body, ~x"//GetOpenIDConnectProviderResult"e,
          url: ~x"./Url/text()"s,
          client_id_list: ~x"./ClientIDList/member/text()"ls,
          thumbprint_list: ~x"./ThumbprintList/member/text()"ls,
          create_date: ~x"./CreateDate/text()"s
        )

      {:ok, fields}
    end)
  end

  @doc """
  Lists the OIDC providers in the account.
  """
  @spec list_open_id_connect_providers(opts :: keyword()) ::
          {:ok, %{open_id_connect_provider_list: list(%{arn: String.t()})}}
          | {:error, term()}
  def list_open_id_connect_providers(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_open_id_connect_providers_response(opts)
    else
      do_list_open_id_connect_providers(opts)
    end
  end

  defp do_list_open_id_connect_providers(opts) do
    "ListOpenIDConnectProviders"
    |> perform(%{}, opts)
    |> deserialize_response(opts, fn body ->
      providers =
        xpath(body, ~x"//OpenIDConnectProviderList/member"l, arn: ~x"./Arn/text()"s)

      {:ok, %{open_id_connect_provider_list: providers}}
    end)
  end

  @doc """
  Deletes an OIDC provider.

  ## Arguments

    * `provider_arn` - The OIDC provider ARN.
    * `opts` - Shared options.
  """
  @spec delete_open_id_connect_provider(provider_arn :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_open_id_connect_provider(provider_arn, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_open_id_connect_provider_response(provider_arn, opts)
    else
      do_delete_open_id_connect_provider(provider_arn, opts)
    end
  end

  defp do_delete_open_id_connect_provider(provider_arn, opts) do
    "DeleteOpenIDConnectProvider"
    |> perform(%{"OpenIDConnectProviderArn" => provider_arn}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Replaces the list of server certificate thumbprints on an OIDC provider.

  ## Arguments

    * `provider_arn` - The OIDC provider ARN.
    * `thumbprint_list` - New list of thumbprints.
    * `opts` - Shared options.
  """
  @spec update_open_id_connect_provider_thumbprint(
          provider_arn :: String.t(),
          thumbprint_list :: list(String.t()),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def update_open_id_connect_provider_thumbprint(provider_arn, thumbprint_list, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_update_open_id_connect_provider_thumbprint_response(provider_arn, opts)
    else
      do_update_open_id_connect_provider_thumbprint(provider_arn, thumbprint_list, opts)
    end
  end

  defp do_update_open_id_connect_provider_thumbprint(provider_arn, thumbprint_list, opts) do
    params =
      %{"OpenIDConnectProviderArn" => provider_arn}
      |> put_member_list("ThumbprintList", thumbprint_list)

    "UpdateOpenIDConnectProviderThumbprint"
    |> perform(params, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Adds a client ID (audience) to an OIDC provider.

  ## Arguments

    * `provider_arn` - The OIDC provider ARN.
    * `client_id` - The client ID to add.
    * `opts` - Shared options.
  """
  @spec add_client_id_to_open_id_connect_provider(
          provider_arn :: String.t(),
          client_id :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def add_client_id_to_open_id_connect_provider(provider_arn, client_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_add_client_id_to_open_id_connect_provider_response(provider_arn, opts)
    else
      do_add_client_id_to_open_id_connect_provider(provider_arn, client_id, opts)
    end
  end

  defp do_add_client_id_to_open_id_connect_provider(provider_arn, client_id, opts) do
    "AddClientIDToOpenIDConnectProvider"
    |> perform(
      %{"OpenIDConnectProviderArn" => provider_arn, "ClientID" => client_id},
      opts
    )
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Removes a client ID (audience) from an OIDC provider.

  ## Arguments

    * `provider_arn` - The OIDC provider ARN.
    * `client_id` - The client ID to remove.
    * `opts` - Shared options.
  """
  @spec remove_client_id_from_open_id_connect_provider(
          provider_arn :: String.t(),
          client_id :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def remove_client_id_from_open_id_connect_provider(provider_arn, client_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_remove_client_id_from_open_id_connect_provider_response(provider_arn, opts)
    else
      do_remove_client_id_from_open_id_connect_provider(provider_arn, client_id, opts)
    end
  end

  defp do_remove_client_id_from_open_id_connect_provider(provider_arn, client_id, opts) do
    "RemoveClientIDFromOpenIDConnectProvider"
    |> perform(
      %{"OpenIDConnectProviderArn" => provider_arn, "ClientID" => client_id},
      opts
    )
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # Account
  # ---------------------------------------------------------------------------

  @doc """
  Returns a summary of IAM entities in the current account.

  Wraps the IAM `GetAccountSummary` action. The response is a flat map of
  integer-valued account attributes such as `"AccountAccessKeysPresent"`,
  `"AccountMFAEnabled"`, `"Users"`, `"Groups"`, `"Roles"`, etc.

  Returns `{:ok, %{summary_map: map()}}` on success.
  """
  @spec get_account_summary(opts :: keyword()) ::
          {:ok, %{summary_map: map()}} | {:error, term()}
  def get_account_summary(opts \\ []) do
    "GetAccountSummary"
    |> perform(%{}, opts)
    |> deserialize_response(opts, fn body ->
      entries =
        xpath(body, ~x"//GetAccountSummaryResult/SummaryMap/entry"l,
          key: ~x"./key/text()"s,
          value: ~x"./value/text()"i
        )

      summary_map = Map.new(entries, fn %{key: k, value: v} -> {k, v} end)
      {:ok, %{summary_map: summary_map}}
    end)
  end

  # ---------------------------------------------------------------------------
  # Sandbox delegation
  # ---------------------------------------------------------------------------

  defp inline_sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    cfg = Config.sandbox()
    sandbox_enabled = sandbox_opts[:enabled] || cfg[:enabled]
    sandbox_mode = sandbox_opts[:mode] || cfg[:mode]

    sandbox_enabled and sandbox_mode === :inline and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    @doc false
    defdelegate sandbox_disabled?, to: AWS.IAM.Sandbox

    # Users
    @doc false
    defdelegate sandbox_create_user_response(name, opts),
      to: AWS.IAM.Sandbox,
      as: :create_user_response

    @doc false
    defdelegate sandbox_get_user_response(name, opts), to: AWS.IAM.Sandbox, as: :get_user_response
    @doc false
    defdelegate sandbox_list_users_response(opts), to: AWS.IAM.Sandbox, as: :list_users_response
    @doc false
    defdelegate sandbox_delete_user_response(name, opts),
      to: AWS.IAM.Sandbox,
      as: :delete_user_response

    # Access Keys
    @doc false
    defdelegate sandbox_create_access_key_response(username, opts),
      to: AWS.IAM.Sandbox,
      as: :create_access_key_response

    @doc false
    defdelegate sandbox_list_access_keys_response(username, opts),
      to: AWS.IAM.Sandbox,
      as: :list_access_keys_response

    @doc false
    defdelegate sandbox_delete_access_key_response(key_id, username, opts),
      to: AWS.IAM.Sandbox,
      as: :delete_access_key_response

    # Groups
    @doc false
    defdelegate sandbox_create_group_response(name, opts),
      to: AWS.IAM.Sandbox,
      as: :create_group_response

    @doc false
    defdelegate sandbox_list_groups_response(opts), to: AWS.IAM.Sandbox, as: :list_groups_response
    @doc false
    defdelegate sandbox_delete_group_response(name, opts),
      to: AWS.IAM.Sandbox,
      as: :delete_group_response

    # Group membership
    @doc false
    defdelegate sandbox_add_user_to_group_response(group, user, opts),
      to: AWS.IAM.Sandbox,
      as: :add_user_to_group_response

    @doc false
    defdelegate sandbox_remove_user_from_group_response(group, user, opts),
      to: AWS.IAM.Sandbox,
      as: :remove_user_from_group_response

    # Roles
    @doc false
    defdelegate sandbox_create_role_response(name, opts),
      to: AWS.IAM.Sandbox,
      as: :create_role_response

    @doc false
    defdelegate sandbox_get_role_response(name, opts), to: AWS.IAM.Sandbox, as: :get_role_response
    @doc false
    defdelegate sandbox_list_roles_response(opts), to: AWS.IAM.Sandbox, as: :list_roles_response
    @doc false
    defdelegate sandbox_delete_role_response(name, opts),
      to: AWS.IAM.Sandbox,
      as: :delete_role_response

    # Policies
    @doc false
    defdelegate sandbox_create_policy_response(name, opts),
      to: AWS.IAM.Sandbox,
      as: :create_policy_response

    @doc false
    defdelegate sandbox_get_policy_response(arn, opts),
      to: AWS.IAM.Sandbox,
      as: :get_policy_response

    @doc false
    defdelegate sandbox_get_policy_version_response(arn, version_id, opts),
      to: AWS.IAM.Sandbox,
      as: :get_policy_version_response

    @doc false
    defdelegate sandbox_list_policies_response(opts),
      to: AWS.IAM.Sandbox,
      as: :list_policies_response

    @doc false
    defdelegate sandbox_delete_policy_response(arn, opts),
      to: AWS.IAM.Sandbox,
      as: :delete_policy_response

    @doc false
    defdelegate sandbox_create_policy_version_response(arn, opts),
      to: AWS.IAM.Sandbox,
      as: :create_policy_version_response

    @doc false
    defdelegate sandbox_set_default_policy_version_response(arn, version_id, opts),
      to: AWS.IAM.Sandbox,
      as: :set_default_policy_version_response

    @doc false
    defdelegate sandbox_delete_policy_version_response(arn, version_id, opts),
      to: AWS.IAM.Sandbox,
      as: :delete_policy_version_response

    @doc false
    defdelegate sandbox_list_policy_versions_response(arn, opts),
      to: AWS.IAM.Sandbox,
      as: :list_policy_versions_response

    # Attachments
    @doc false
    defdelegate sandbox_attach_role_policy_response(role, arn, opts),
      to: AWS.IAM.Sandbox,
      as: :attach_role_policy_response

    @doc false
    defdelegate sandbox_detach_role_policy_response(role, arn, opts),
      to: AWS.IAM.Sandbox,
      as: :detach_role_policy_response

    @doc false
    defdelegate sandbox_list_attached_role_policies_response(role, opts),
      to: AWS.IAM.Sandbox,
      as: :list_attached_role_policies_response

    @doc false
    defdelegate sandbox_attach_user_policy_response(user, arn, opts),
      to: AWS.IAM.Sandbox,
      as: :attach_user_policy_response

    @doc false
    defdelegate sandbox_detach_user_policy_response(user, arn, opts),
      to: AWS.IAM.Sandbox,
      as: :detach_user_policy_response

    @doc false
    defdelegate sandbox_attach_group_policy_response(group, arn, opts),
      to: AWS.IAM.Sandbox,
      as: :attach_group_policy_response

    @doc false
    defdelegate sandbox_detach_group_policy_response(group, arn, opts),
      to: AWS.IAM.Sandbox,
      as: :detach_group_policy_response

    # MFA Devices
    @doc false
    defdelegate sandbox_list_mfa_devices_response(username, opts),
      to: AWS.IAM.Sandbox,
      as: :list_mfa_devices_response

    # Role Policies
    @doc false
    defdelegate sandbox_update_assume_role_policy_response(role_name, opts),
      to: AWS.IAM.Sandbox,
      as: :update_assume_role_policy_response

    @doc false
    defdelegate sandbox_put_role_policy_response(role_name, policy_name, opts),
      to: AWS.IAM.Sandbox,
      as: :put_role_policy_response

    @doc false
    defdelegate sandbox_get_role_policy_response(role_name, policy_name, opts),
      to: AWS.IAM.Sandbox,
      as: :get_role_policy_response

    @doc false
    defdelegate sandbox_delete_role_policy_response(role_name, policy_name, opts),
      to: AWS.IAM.Sandbox,
      as: :delete_role_policy_response

    @doc false
    defdelegate sandbox_list_role_policies_response(role_name, opts),
      to: AWS.IAM.Sandbox,
      as: :list_role_policies_response

    # OIDC Providers
    @doc false
    defdelegate sandbox_create_open_id_connect_provider_response(url, opts),
      to: AWS.IAM.Sandbox,
      as: :create_open_id_connect_provider_response

    @doc false
    defdelegate sandbox_get_open_id_connect_provider_response(arn, opts),
      to: AWS.IAM.Sandbox,
      as: :get_open_id_connect_provider_response

    @doc false
    defdelegate sandbox_list_open_id_connect_providers_response(opts),
      to: AWS.IAM.Sandbox,
      as: :list_open_id_connect_providers_response

    @doc false
    defdelegate sandbox_delete_open_id_connect_provider_response(arn, opts),
      to: AWS.IAM.Sandbox,
      as: :delete_open_id_connect_provider_response

    @doc false
    defdelegate sandbox_update_open_id_connect_provider_thumbprint_response(arn, opts),
      to: AWS.IAM.Sandbox,
      as: :update_open_id_connect_provider_thumbprint_response

    @doc false
    defdelegate sandbox_add_client_id_to_open_id_connect_provider_response(arn, opts),
      to: AWS.IAM.Sandbox,
      as: :add_client_id_to_open_id_connect_provider_response

    @doc false
    defdelegate sandbox_remove_client_id_from_open_id_connect_provider_response(arn, opts),
      to: AWS.IAM.Sandbox,
      as: :remove_client_id_from_open_id_connect_provider_response
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
    defp sandbox_get_policy_version_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_list_policies_response(_), do: raise("sandbox not available")
    defp sandbox_delete_policy_response(_, _), do: raise("sandbox not available")
    defp sandbox_create_policy_version_response(_, _), do: raise("sandbox not available")
    defp sandbox_set_default_policy_version_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_delete_policy_version_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_list_policy_versions_response(_, _), do: raise("sandbox not available")

    # Attachments
    defp sandbox_attach_role_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_detach_role_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_list_attached_role_policies_response(_, _), do: raise("sandbox not available")
    defp sandbox_attach_user_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_detach_user_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_attach_group_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_detach_group_policy_response(_, _, _), do: raise("sandbox not available")

    # MFA Devices
    defp sandbox_list_mfa_devices_response(_, _), do: raise("sandbox not available")

    # Role Policies
    defp sandbox_update_assume_role_policy_response(_, _), do: raise("sandbox not available")
    defp sandbox_put_role_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_get_role_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_delete_role_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_list_role_policies_response(_, _), do: raise("sandbox not available")

    # OIDC Providers
    defp sandbox_create_open_id_connect_provider_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_get_open_id_connect_provider_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_list_open_id_connect_providers_response(_),
      do: raise("sandbox not available")

    defp sandbox_delete_open_id_connect_provider_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_update_open_id_connect_provider_thumbprint_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_add_client_id_to_open_id_connect_provider_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_remove_client_id_from_open_id_connect_provider_response(_, _),
      do: raise("sandbox not available")
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @doc false
  def build_operation(action, params, opts) do
    opts = Keyword.put_new(opts, :region, @default_region)

    with {:ok, config} <- Client.resolve_config(:iam, opts, fn _region -> @default_host end) do
      op = %Operation{
        method: :post,
        url: Client.simple_url(config),
        headers: [{"content-type", @content_type}],
        body: encode_body(action, params),
        service: @service,
        region: config.region,
        access_key_id: config.access_key_id,
        secret_access_key: config.secret_access_key,
        security_token: config.security_token,
        http: Keyword.get(opts, :http, [])
      }

      {:ok, apply_overrides(op, opts[:iam] || [])}
    end
  end

  defp perform(action, params, opts) do
    with {:ok, op} <- build_operation(action, params, opts) do
      case Client.execute(op) do
        {:ok, %{body: body}} -> {:ok, body}
        {:error, _} = err -> err
      end
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

  defp encode_body(action, params) do
    params
    |> Map.merge(%{"Action" => action, "Version" => @api_version})
    |> URI.encode_query()
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

  defp put_member_list(map, prefix, values) when is_list(values) do
    values
    |> Enum.with_index(1)
    |> Enum.reduce(map, fn {value, idx}, acc ->
      Map.put(acc, "#{prefix}.member.#{idx}", value)
    end)
  end

  defp parse_user(body, path) do
    xpath(body, path,
      user_name: ~x"./UserName/text()"s,
      user_id: ~x"./UserId/text()"s,
      arn: ~x"./Arn/text()"s,
      path: ~x"./Path/text()"s,
      create_date: ~x"./CreateDate/text()"s
    )
  end

  defp parse_access_key(body, path) do
    xpath(body, path,
      access_key_id: ~x"./AccessKeyId/text()"s,
      secret_access_key: ~x"./SecretAccessKey/text()"s,
      user_name: ~x"./UserName/text()"s,
      status: ~x"./Status/text()"s,
      create_date: ~x"./CreateDate/text()"s
    )
  end

  defp parse_group(body, path) do
    xpath(body, path,
      group_name: ~x"./GroupName/text()"s,
      group_id: ~x"./GroupId/text()"s,
      arn: ~x"./Arn/text()"s,
      path: ~x"./Path/text()"s,
      create_date: ~x"./CreateDate/text()"s
    )
  end

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
