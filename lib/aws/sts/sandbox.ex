if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.STS.Sandbox do
    use AWS.Sandbox,
      registry: :aws_sts_sandbox,
      operations: [get_caller_identity: []]
  end
end
