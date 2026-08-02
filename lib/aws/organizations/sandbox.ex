if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.Organizations.Sandbox do
    use AWS.Sandbox,
      registry: :aws_organizations_sandbox,
      operations: [
        create_organization: [],
        delete_organization: [],
        describe_organization: [],
        create_organizational_unit: [:name],
        delete_organizational_unit: [:ou_id],
        list_organizational_units_for_parent: [:parent_id],
        create_account: [:name],
        describe_create_account_status: [:request_id],
        move_account: [:account_id],
        close_account: [:account_id],
        list_accounts: [],
        list_roots: [],
        register_delegated_administrator: [:account_id],
        enable_aws_service_access: [:service_principal],
        list_delegated_administrators: [],
        list_aws_service_access_for_organization: [],
        list_parents: [:child_id],
        describe_account: [:account_id],
        describe_organizational_unit: [:ou_id],
        update_organizational_unit: [:ou_id],
        disable_aws_service_access: [:service_principal],
        deregister_delegated_administrator: [:account_id],
        list_children: [:parent_id]
      ]
  end
end
