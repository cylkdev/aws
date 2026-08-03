if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.STS.Sandbox do
    @moduledoc false

    @registry :aws_sts_sandbox

    def start_link, do: AwsSdk.Sandbox.start_link(@registry)

    @spec disable_aws_sts_sandbox(map) :: :ok
    def disable_aws_sts_sandbox(_context), do: AwsSdk.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AwsSdk.Sandbox.disabled?(@registry, __MODULE__)

    def get_caller_identity_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :get_caller_identity, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_get_caller_identity_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_caller_identity,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
