if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.IdentityCenter.Sandbox do
    use AWS.Sandbox,
      registry: :aws_identity_center_sandbox,
      operations: [
        list_instances: [],
        create_permission_set: [:name],
        delete_permission_set: [:arn],
        list_permission_sets: [:instance_arn],
        describe_permission_set: [:instance_arn, :permission_set_arn],
        get_inline_policy_for_permission_set: [:instance_arn, :permission_set_arn],
        put_inline_policy_to_permission_set: [:instance_arn, :permission_set_arn, :policy],
        list_managed_policies_in_permission_set: [:instance_arn, :permission_set_arn],
        list_account_assignments: [:instance_arn, :account_id, :permission_set_arn],
        list_accounts_for_provisioned_permission_set: [:instance_arn, :permission_set_arn],
        attach_managed_policy_to_permission_set: [:ps_arn],
        detach_managed_policy_from_permission_set: [:ps_arn],
        create_account_assignment: [:instance_arn],
        delete_account_assignment: [:instance_arn],
        provision_permission_set: [:permission_set_arn],
        create_identity_store_user: [:username],
        delete_identity_store_user: [:user_id],
        update_identity_store_user: [:user_id],
        describe_identity_store_user: [:user_id],
        describe_identity_store_group: [:group_id],
        list_identity_store_users: [:store_id],
        create_identity_store_group: [:name],
        delete_identity_store_group: [:group_id],
        list_identity_store_groups: [:store_id],
        create_group_membership: [:group_id],
        delete_group_membership: [:membership_id]
      ]
  end
end
