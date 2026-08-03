if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.IAM.Sandbox do
    @moduledoc false

    @registry :aws_iam_sandbox

    def start_link, do: AWS.Sandbox.start_link(@registry)

    @spec disable_aws_iam_sandbox(map) :: :ok
    def disable_aws_iam_sandbox(_context), do: AWS.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AWS.Sandbox.disabled?(@registry, __MODULE__)

    def create_user_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_user, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_user_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_user,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_user_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_user, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_get_user_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_user,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_users_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_users, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_users_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_users,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_user_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_user, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_user_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_user,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_access_key_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_access_key, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_create_access_key_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_access_key,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_access_keys_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_access_keys, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_access_keys_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_access_keys,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_access_key_response(key_id, opts) do
      examples = AWS.Sandbox.doc_examples([:key_id])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_access_key, key_id, examples)
      AWS.Sandbox.apply_func(func, [key_id, opts], examples)
    end

    def set_delete_access_key_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_access_key,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_group_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_group, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_group_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_group,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_groups_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_groups, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_groups_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_groups,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_group_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_group, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_group_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_group,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def add_user_to_group_response(group, user, opts) do
      examples = AWS.Sandbox.doc_examples([:group, :user])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :add_user_to_group, group, examples)
      AWS.Sandbox.apply_func(func, [group, user, opts], examples)
    end

    def set_add_user_to_group_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :add_user_to_group,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def remove_user_from_group_response(group, user, opts) do
      examples = AWS.Sandbox.doc_examples([:group, :user])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :remove_user_from_group, group, examples)
      AWS.Sandbox.apply_func(func, [group, user, opts], examples)
    end

    def set_remove_user_from_group_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :remove_user_from_group,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_role_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_role, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_role_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_role,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_role_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_role, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_get_role_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_role,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_roles_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_roles, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_roles_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_roles,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_role_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_role, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_role_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_role,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_policy_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_policy, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_policy_response(arn, opts) do
      examples = AWS.Sandbox.doc_examples([:arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_policy, arn, examples)
      AWS.Sandbox.apply_func(func, [arn, opts], examples)
    end

    def set_get_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_policy_version_response(arn, version_id, opts) do
      examples = AWS.Sandbox.doc_examples([:arn, :version_id])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_policy_version, arn, examples)
      AWS.Sandbox.apply_func(func, [arn, version_id, opts], examples)
    end

    def set_get_policy_version_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_policy_version,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_policy_version_response(arn, opts) do
      examples = AWS.Sandbox.doc_examples([:arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_policy_version, arn, examples)
      AWS.Sandbox.apply_func(func, [arn, opts], examples)
    end

    def set_create_policy_version_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_policy_version,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def set_default_policy_version_response(arn, version_id, opts) do
      examples = AWS.Sandbox.doc_examples([:arn, :version_id])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :set_default_policy_version, arn, examples)
      AWS.Sandbox.apply_func(func, [arn, version_id, opts], examples)
    end

    def set_set_default_policy_version_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :set_default_policy_version,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_policy_version_response(arn, version_id, opts) do
      examples = AWS.Sandbox.doc_examples([:arn, :version_id])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_policy_version, arn, examples)
      AWS.Sandbox.apply_func(func, [arn, version_id, opts], examples)
    end

    def set_delete_policy_version_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_policy_version,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_policy_versions_response(arn, opts) do
      examples = AWS.Sandbox.doc_examples([:arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_policy_versions, arn, examples)
      AWS.Sandbox.apply_func(func, [arn, opts], examples)
    end

    def set_list_policy_versions_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_policy_versions,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_policies_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_policies, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_policies_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_policies,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_policy_response(arn, opts) do
      examples = AWS.Sandbox.doc_examples([:arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_policy, arn, examples)
      AWS.Sandbox.apply_func(func, [arn, opts], examples)
    end

    def set_delete_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def attach_role_policy_response(role, policy_arn, opts) do
      examples = AWS.Sandbox.doc_examples([:role, :policy_arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :attach_role_policy, role, examples)
      AWS.Sandbox.apply_func(func, [role, policy_arn, opts], examples)
    end

    def set_attach_role_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :attach_role_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def detach_role_policy_response(role, policy_arn, opts) do
      examples = AWS.Sandbox.doc_examples([:role, :policy_arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :detach_role_policy, role, examples)
      AWS.Sandbox.apply_func(func, [role, policy_arn, opts], examples)
    end

    def set_detach_role_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :detach_role_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_attached_role_policies_response(role, opts) do
      examples = AWS.Sandbox.doc_examples([:role])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :list_attached_role_policies, role, examples)

      AWS.Sandbox.apply_func(func, [role, opts], examples)
    end

    def set_list_attached_role_policies_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_attached_role_policies,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def attach_user_policy_response(user, policy_arn, opts) do
      examples = AWS.Sandbox.doc_examples([:user, :policy_arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :attach_user_policy, user, examples)
      AWS.Sandbox.apply_func(func, [user, policy_arn, opts], examples)
    end

    def set_attach_user_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :attach_user_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def detach_user_policy_response(user, policy_arn, opts) do
      examples = AWS.Sandbox.doc_examples([:user, :policy_arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :detach_user_policy, user, examples)
      AWS.Sandbox.apply_func(func, [user, policy_arn, opts], examples)
    end

    def set_detach_user_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :detach_user_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def attach_group_policy_response(group, policy_arn, opts) do
      examples = AWS.Sandbox.doc_examples([:group, :policy_arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :attach_group_policy, group, examples)
      AWS.Sandbox.apply_func(func, [group, policy_arn, opts], examples)
    end

    def set_attach_group_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :attach_group_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def detach_group_policy_response(group, policy_arn, opts) do
      examples = AWS.Sandbox.doc_examples([:group, :policy_arn])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :detach_group_policy, group, examples)
      AWS.Sandbox.apply_func(func, [group, policy_arn, opts], examples)
    end

    def set_detach_group_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :detach_group_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_mfa_devices_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_mfa_devices, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_mfa_devices_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_mfa_devices,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def update_assume_role_policy_response(role_name, opts) do
      examples = AWS.Sandbox.doc_examples([:role_name])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :update_assume_role_policy, role_name, examples)

      AWS.Sandbox.apply_func(func, [role_name, opts], examples)
    end

    def set_update_assume_role_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :update_assume_role_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_role_policy_response(role_name, policy_name, opts) do
      examples = AWS.Sandbox.doc_examples([:role_name, :policy_name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :put_role_policy, role_name, examples)
      AWS.Sandbox.apply_func(func, [role_name, policy_name, opts], examples)
    end

    def set_put_role_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_role_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_role_policy_response(role_name, policy_name, opts) do
      examples = AWS.Sandbox.doc_examples([:role_name, :policy_name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_role_policy, role_name, examples)
      AWS.Sandbox.apply_func(func, [role_name, policy_name, opts], examples)
    end

    def set_get_role_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_role_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_role_policy_response(role_name, policy_name, opts) do
      examples = AWS.Sandbox.doc_examples([:role_name, :policy_name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_role_policy, role_name, examples)
      AWS.Sandbox.apply_func(func, [role_name, policy_name, opts], examples)
    end

    def set_delete_role_policy_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_role_policy,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_role_policies_response(role_name, opts) do
      examples = AWS.Sandbox.doc_examples([:role_name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_role_policies, role_name, examples)
      AWS.Sandbox.apply_func(func, [role_name, opts], examples)
    end

    def set_list_role_policies_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_role_policies,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_open_id_connect_provider_response(url, opts) do
      examples = AWS.Sandbox.doc_examples([:url])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :create_open_id_connect_provider, url, examples)

      AWS.Sandbox.apply_func(func, [url, opts], examples)
    end

    def set_create_open_id_connect_provider_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_open_id_connect_provider,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_open_id_connect_provider_response(arn, opts) do
      examples = AWS.Sandbox.doc_examples([:arn])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :get_open_id_connect_provider, arn, examples)

      AWS.Sandbox.apply_func(func, [arn, opts], examples)
    end

    def set_get_open_id_connect_provider_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_open_id_connect_provider,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_open_id_connect_providers_response(opts) do
      examples = AWS.Sandbox.doc_examples([])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :list_open_id_connect_providers, "*", examples)

      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_open_id_connect_providers_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_open_id_connect_providers,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_account_summary_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_account_summary, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_get_account_summary_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_account_summary,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_open_id_connect_provider_response(arn, opts) do
      examples = AWS.Sandbox.doc_examples([:arn])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :delete_open_id_connect_provider, arn, examples)

      AWS.Sandbox.apply_func(func, [arn, opts], examples)
    end

    def set_delete_open_id_connect_provider_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_open_id_connect_provider,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def update_open_id_connect_provider_thumbprint_response(arn, opts) do
      examples = AWS.Sandbox.doc_examples([:arn])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :update_open_id_connect_provider_thumbprint,
          arn,
          examples
        )

      AWS.Sandbox.apply_func(func, [arn, opts], examples)
    end

    def set_update_open_id_connect_provider_thumbprint_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :update_open_id_connect_provider_thumbprint,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def add_client_id_to_open_id_connect_provider_response(arn, opts) do
      examples = AWS.Sandbox.doc_examples([:arn])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :add_client_id_to_open_id_connect_provider,
          arn,
          examples
        )

      AWS.Sandbox.apply_func(func, [arn, opts], examples)
    end

    def set_add_client_id_to_open_id_connect_provider_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :add_client_id_to_open_id_connect_provider,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def remove_client_id_from_open_id_connect_provider_response(arn, opts) do
      examples = AWS.Sandbox.doc_examples([:arn])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :remove_client_id_from_open_id_connect_provider,
          arn,
          examples
        )

      AWS.Sandbox.apply_func(func, [arn, opts], examples)
    end

    def set_remove_client_id_from_open_id_connect_provider_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :remove_client_id_from_open_id_connect_provider,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
