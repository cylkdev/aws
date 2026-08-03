if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.STS.Sandbox do
    @moduledoc false

    @registry :aws_sts_sandbox

    def start_link, do: AWS.Sandbox.start_link(@registry)

    @spec disable_aws_sts_sandbox(map) :: :ok
    def disable_aws_sts_sandbox(_context), do: AWS.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AWS.Sandbox.disabled?(@registry, __MODULE__)

    def get_caller_identity_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_caller_identity, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_get_caller_identity_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_caller_identity,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
