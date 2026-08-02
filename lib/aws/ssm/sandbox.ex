if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.SSM.Sandbox do
    use AWS.Sandbox,
      registry: :aws_ssm_sandbox,
      operations: [
        get_parameter: [:name],
        # A list of names has no single scalar to key on.
        get_parameters: {[:names], fn _ -> "*" end},
        get_parameters_by_path: [:path],
        put_parameter: [:name, :value],
        delete_parameter: [:name],
        delete_parameters: {[:names], fn _ -> "*" end},
        describe_parameters: [],
        describe_instance_information: []
      ]
  end
end
