if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.SSM.Sandbox do
    @moduledoc false

    @registry :aws_ssm_sandbox

    def start_link, do: AWS.Sandbox.start_link(@registry)

    @spec disable_aws_ssm_sandbox(map) :: :ok
    def disable_aws_ssm_sandbox(_context), do: AWS.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AWS.Sandbox.disabled?(@registry, __MODULE__)

    def get_parameter_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_parameter, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_get_parameter_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_parameter,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_parameters_response(names, opts) do
      examples = AWS.Sandbox.doc_examples([:names])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_parameters, "*", examples)
      AWS.Sandbox.apply_func(func, [names, opts], examples)
    end

    def set_get_parameters_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_parameters,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_parameters_by_path_response(path, opts) do
      examples = AWS.Sandbox.doc_examples([:path])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_parameters_by_path, path, examples)
      AWS.Sandbox.apply_func(func, [path, opts], examples)
    end

    def set_get_parameters_by_path_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_parameters_by_path,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_parameter_response(name, value, opts) do
      examples = AWS.Sandbox.doc_examples([:name, :value])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :put_parameter, name, examples)
      AWS.Sandbox.apply_func(func, [name, value, opts], examples)
    end

    def set_put_parameter_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_parameter,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_parameter_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_parameter, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_delete_parameter_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_parameter,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_parameters_response(names, opts) do
      examples = AWS.Sandbox.doc_examples([:names])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_parameters, "*", examples)
      AWS.Sandbox.apply_func(func, [names, opts], examples)
    end

    def set_delete_parameters_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_parameters,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_parameters_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_parameters, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_parameters_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_parameters,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_instance_information_response(opts) do
      examples = AWS.Sandbox.doc_examples([])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :describe_instance_information, "*", examples)

      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_instance_information_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_instance_information,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
