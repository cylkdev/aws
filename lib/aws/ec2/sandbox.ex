if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.EC2.Sandbox do
    @moduledoc false

    @registry :aws_ec2_sandbox

    def start_link, do: AWS.Sandbox.start_link(@registry)

    @spec disable_aws_ec2_sandbox(map) :: :ok
    def disable_aws_ec2_sandbox(_context), do: AWS.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AWS.Sandbox.disabled?(@registry, __MODULE__)

    def create_security_group_response(name, opts) do
      examples = AWS.Sandbox.doc_examples([:name])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_security_group, name, examples)
      AWS.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_security_group_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_security_group,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_security_groups_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_security_groups, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_security_groups_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_security_groups,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_security_group_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_security_group, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_delete_security_group_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_security_group,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def authorize_security_group_ingress_response(group_id, opts) do
      examples = AWS.Sandbox.doc_examples([:group_id])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :authorize_security_group_ingress,
          group_id,
          examples
        )

      AWS.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_authorize_security_group_ingress_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :authorize_security_group_ingress,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def revoke_security_group_ingress_response(group_id, opts) do
      examples = AWS.Sandbox.doc_examples([:group_id])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :revoke_security_group_ingress,
          group_id,
          examples
        )

      AWS.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_revoke_security_group_ingress_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :revoke_security_group_ingress,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def authorize_security_group_egress_response(group_id, opts) do
      examples = AWS.Sandbox.doc_examples([:group_id])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :authorize_security_group_egress,
          group_id,
          examples
        )

      AWS.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_authorize_security_group_egress_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :authorize_security_group_egress,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def revoke_security_group_egress_response(group_id, opts) do
      examples = AWS.Sandbox.doc_examples([:group_id])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :revoke_security_group_egress,
          group_id,
          examples
        )

      AWS.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_revoke_security_group_egress_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :revoke_security_group_egress,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_vpcs_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_vpcs, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_vpcs_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_vpcs,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_subnets_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_subnets, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_subnets_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_subnets,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_instances_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_instances, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_instances_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_instances,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_images_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_images, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_images_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_images,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def deregister_image_response(image_id, opts) do
      examples = AWS.Sandbox.doc_examples([:image_id])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :deregister_image, image_id, examples)
      AWS.Sandbox.apply_func(func, [image_id, opts], examples)
    end

    def set_deregister_image_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :deregister_image,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_snapshot_response(snapshot_id, opts) do
      examples = AWS.Sandbox.doc_examples([:snapshot_id])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_snapshot, snapshot_id, examples)
      AWS.Sandbox.apply_func(func, [snapshot_id, opts], examples)
    end

    def set_delete_snapshot_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_snapshot,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_tags_response(resource_ids, opts) do
      examples = AWS.Sandbox.doc_examples([:resource_ids])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :create_tags,
          List.first(resource_ids) || "*",
          examples
        )

      AWS.Sandbox.apply_func(func, [resource_ids, opts], examples)
    end

    def set_create_tags_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_tags,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_tags_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :describe_tags, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_tags_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_tags,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
