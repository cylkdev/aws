defmodule AWS.Service do
  @moduledoc false

  # Shared plumbing for the service facades:
  #
  #     use AWS.Service, sandbox: AWS.SSM.Sandbox,
  #       operations: [get_parameter: 2, put_parameter: 3, ...]
  #
  # Generates `sandbox?/1`, `apply_overrides/2`, `deserialize_response/3`, and
  # the `sandbox_<op>_response/N` delegates each service used to hand-write
  # inside an `if Code.ensure_loaded?(SandboxRegistry)` block. Public functions
  # keep the existing shape:
  #
  #     def get_parameter(name, opts \\ []) do
  #       if sandbox?(opts) do
  #         sandbox_get_parameter_response(name, opts)
  #       else
  #         do_get_parameter(name, opts)
  #       end
  #     end

  @override_keys [:headers, :body, :http, :url, :stream_upload, :stream_response, :payload_hash]

  def apply_overrides(op, overrides) do
    Enum.reduce(@override_keys, op, fn key, acc ->
      case Keyword.fetch(overrides, key) do
        {:ok, value} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  defmacro __using__(opts) do
    sandbox = Keyword.fetch!(opts, :sandbox)
    operations = Keyword.fetch!(opts, :operations)

    delegates =
      for {op, arity} <- operations do
        args = Macro.generate_arguments(arity, __MODULE__)

        quote do
          defp unquote(:"sandbox_#{op}_response")(unquote_splicing(args)) do
            AWS.Service.sandbox_response(unquote(sandbox), unquote(op), unquote(args))
          end
        end
      end

    quote do
      @aws_sandbox unquote(sandbox)

      defp sandbox?(opts) do
        enabled = Keyword.get(opts[:sandbox] || [], :enabled, AWS.Config.sandbox()[:enabled])
        enabled and not AWS.Service.sandbox_disabled?(@aws_sandbox)
      end

      defp apply_overrides(op, overrides), do: AWS.Service.apply_overrides(op, overrides)

      defp deserialize_response(result, opts, func),
        do: AWS.Response.handle(result, opts, func)

      unquote(delegates)
    end
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    def sandbox_disabled?(sandbox), do: sandbox.sandbox_disabled?()

    def sandbox_response(sandbox, op, args), do: apply(sandbox, :"#{op}_response", args)
  else
    def sandbox_disabled?(_sandbox), do: false

    def sandbox_response(_sandbox, _op, _args), do: raise("sandbox not available")
  end
end
