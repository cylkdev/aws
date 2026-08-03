if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.IdentityCenter.Sandbox do
    @moduledoc false

    @registry :aws_identity_center_sandbox

    def start_link, do: AwsSdk.Sandbox.start_link(@registry)

    @spec disable_aws_identity_center_sandbox(map) :: :ok
    def disable_aws_identity_center_sandbox(_context),
      do: AwsSdk.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AwsSdk.Sandbox.disabled?(@registry, __MODULE__)

    def list_instances_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_instances, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_instances_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_instances,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_permission_set_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_permission_set, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_permission_set_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_permission_set,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_permission_set_response(arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:arn])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_permission_set, arn, examples)
      AwsSdk.Sandbox.apply_func(func, [arn, opts], examples)
    end

    def set_delete_permission_set_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_permission_set,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_permission_sets_response(instance_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_arn])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_permission_sets, instance_arn, examples)

      AwsSdk.Sandbox.apply_func(func, [instance_arn, opts], examples)
    end

    def set_list_permission_sets_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_permission_sets,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_permission_set_response(instance_arn, permission_set_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_arn, :permission_set_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_permission_set,
          instance_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [instance_arn, permission_set_arn, opts], examples)
    end

    def set_describe_permission_set_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_permission_set,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_inline_policy_for_permission_set_response(instance_arn, permission_set_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_arn, :permission_set_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :get_inline_policy_for_permission_set,
          instance_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [instance_arn, permission_set_arn, opts], examples)
    end

    def set_get_inline_policy_for_permission_set_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_inline_policy_for_permission_set,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_inline_policy_to_permission_set_response(
          instance_arn,
          permission_set_arn,
          policy,
          opts
        ) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_arn, :permission_set_arn, :policy])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :put_inline_policy_to_permission_set,
          instance_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [instance_arn, permission_set_arn, policy, opts], examples)
    end

    def set_put_inline_policy_to_permission_set_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_inline_policy_to_permission_set,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_managed_policies_in_permission_set_response(instance_arn, permission_set_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_arn, :permission_set_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :list_managed_policies_in_permission_set,
          instance_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [instance_arn, permission_set_arn, opts], examples)
    end

    def set_list_managed_policies_in_permission_set_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_managed_policies_in_permission_set,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_account_assignments_response(instance_arn, account_id, permission_set_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_arn, :account_id, :permission_set_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :list_account_assignments,
          instance_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(
        func,
        [instance_arn, account_id, permission_set_arn, opts],
        examples
      )
    end

    def set_list_account_assignments_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_account_assignments,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_accounts_for_provisioned_permission_set_response(
          instance_arn,
          permission_set_arn,
          opts
        ) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_arn, :permission_set_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :list_accounts_for_provisioned_permission_set,
          instance_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [instance_arn, permission_set_arn, opts], examples)
    end

    def set_list_accounts_for_provisioned_permission_set_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_accounts_for_provisioned_permission_set,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def attach_managed_policy_to_permission_set_response(ps_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:ps_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :attach_managed_policy_to_permission_set,
          ps_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [ps_arn, opts], examples)
    end

    def set_attach_managed_policy_to_permission_set_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :attach_managed_policy_to_permission_set,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def detach_managed_policy_from_permission_set_response(ps_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:ps_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :detach_managed_policy_from_permission_set,
          ps_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [ps_arn, opts], examples)
    end

    def set_detach_managed_policy_from_permission_set_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :detach_managed_policy_from_permission_set,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_account_assignment_response(instance_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :create_account_assignment,
          instance_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [instance_arn, opts], examples)
    end

    def set_create_account_assignment_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_account_assignment,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_account_assignment_response(instance_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :delete_account_assignment,
          instance_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [instance_arn, opts], examples)
    end

    def set_delete_account_assignment_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_account_assignment,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def provision_permission_set_response(permission_set_arn, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:permission_set_arn])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :provision_permission_set,
          permission_set_arn,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [permission_set_arn, opts], examples)
    end

    def set_provision_permission_set_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :provision_permission_set,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_identity_store_user_response(username, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:username])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :create_identity_store_user,
          username,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [username, opts], examples)
    end

    def set_create_identity_store_user_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_identity_store_user,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_identity_store_user_response(user_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:user_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :delete_identity_store_user,
          user_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [user_id, opts], examples)
    end

    def set_delete_identity_store_user_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_identity_store_user,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def update_identity_store_user_response(user_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:user_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :update_identity_store_user,
          user_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [user_id, opts], examples)
    end

    def set_update_identity_store_user_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :update_identity_store_user,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_identity_store_user_response(user_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:user_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_identity_store_user,
          user_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [user_id, opts], examples)
    end

    def set_describe_identity_store_user_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_identity_store_user,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_identity_store_group_response(group_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_identity_store_group,
          group_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_describe_identity_store_group_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_identity_store_group,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_identity_store_users_response(store_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:store_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :list_identity_store_users,
          store_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [store_id, opts], examples)
    end

    def set_list_identity_store_users_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_identity_store_users,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_identity_store_group_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_identity_store_group, name, examples)

      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_identity_store_group_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_identity_store_group,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_identity_store_group_response(group_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :delete_identity_store_group,
          group_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_delete_identity_store_group_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_identity_store_group,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_identity_store_groups_response(store_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:store_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :list_identity_store_groups,
          store_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [store_id, opts], examples)
    end

    def set_list_identity_store_groups_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_identity_store_groups,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_group_membership_response(group_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group_id])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_group_membership, group_id, examples)

      AwsSdk.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_create_group_membership_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_group_membership,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_group_membership_response(membership_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:membership_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :delete_group_membership,
          membership_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [membership_id, opts], examples)
    end

    def set_delete_group_membership_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_group_membership,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
