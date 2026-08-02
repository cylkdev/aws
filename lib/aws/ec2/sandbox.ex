if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.EC2.Sandbox do
    use AWS.Sandbox,
      registry: :aws_ec2_sandbox,
      operations: [
        create_security_group: [:name],
        describe_security_groups: [],
        delete_security_group: [],
        authorize_security_group_ingress: [:group_id],
        revoke_security_group_ingress: [:group_id],
        authorize_security_group_egress: [:group_id],
        revoke_security_group_egress: [:group_id],
        describe_vpcs: [],
        describe_subnets: [],
        describe_instances: [],
        describe_images: [],
        deregister_image: [:image_id],
        delete_snapshot: [:snapshot_id],
        # Keys on the first resource id; falls back to the wildcard when empty.
        create_tags: {[:resource_ids], fn [ids] -> List.first(ids) || "*" end},
        describe_tags: []
      ]
  end
end
