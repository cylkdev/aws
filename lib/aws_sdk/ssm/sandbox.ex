if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.SSM.Sandbox do
    @moduledoc false

    @registry :aws_ssm_sandbox

    def start_link, do: AwsSdk.Sandbox.start_link(@registry)

    @spec disable_aws_ssm_sandbox(map) :: :ok
    def disable_aws_ssm_sandbox(_context), do: AwsSdk.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AwsSdk.Sandbox.disabled?(@registry, __MODULE__)

    def get_parameter_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :get_parameter, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_get_parameter_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_parameter,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_parameters_response(names, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:names])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :get_parameters, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [names, opts], examples)
    end

    def set_get_parameters_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_parameters,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_parameters_by_path_response(path, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:path])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :get_parameters_by_path, path, examples)
      AwsSdk.Sandbox.apply_func(func, [path, opts], examples)
    end

    def set_get_parameters_by_path_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_parameters_by_path,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_parameter_response(name, value, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name, :value])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :put_parameter, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, value, opts], examples)
    end

    def set_put_parameter_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_parameter,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_parameter_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_parameter, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_parameter_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_parameter,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_parameters_response(names, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:names])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_parameters, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [names, opts], examples)
    end

    def set_delete_parameters_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_parameters,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_parameters_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_parameters, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_parameters_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_parameters,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_instance_information_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_instance_information, "*", examples)

      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_instance_information_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_instance_information,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def send_command_response(instance_ids, document_name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_ids, :document_name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :send_command, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [instance_ids, document_name, opts], examples)
    end

    def set_send_command_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :send_command,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def send_command_by_targets_response(targets, document_name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:targets, :document_name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :send_command_by_targets, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [targets, document_name, opts], examples)
    end

    def set_send_command_by_targets_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :send_command_by_targets,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_command_invocation_response(command_id, instance_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:command_id, :instance_id])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :get_command_invocation, command_id, examples)

      AwsSdk.Sandbox.apply_func(func, [command_id, instance_id, opts], examples)
    end

    def set_get_command_invocation_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_command_invocation,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
