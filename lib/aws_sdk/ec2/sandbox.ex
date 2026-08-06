if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.EC2.Sandbox do
    @moduledoc false

    @registry :aws_ec2_sandbox

    def start_link, do: AwsSdk.Sandbox.start_link(@registry)

    @spec disable_aws_ec2_sandbox(map) :: :ok
    def disable_aws_ec2_sandbox(_context), do: AwsSdk.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AwsSdk.Sandbox.disabled?(@registry, __MODULE__)

    def create_security_group_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_security_group, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_security_group_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_security_group,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_security_groups_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_security_groups, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_security_groups_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_security_groups,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_security_group_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_security_group, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_delete_security_group_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_security_group,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def authorize_security_group_ingress_response(group_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :authorize_security_group_ingress,
          group_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_authorize_security_group_ingress_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :authorize_security_group_ingress,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def revoke_security_group_ingress_response(group_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :revoke_security_group_ingress,
          group_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_revoke_security_group_ingress_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :revoke_security_group_ingress,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def authorize_security_group_egress_response(group_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :authorize_security_group_egress,
          group_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_authorize_security_group_egress_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :authorize_security_group_egress,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def revoke_security_group_egress_response(group_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:group_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :revoke_security_group_egress,
          group_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [group_id, opts], examples)
    end

    def set_revoke_security_group_egress_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :revoke_security_group_egress,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_vpcs_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_vpcs, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_vpcs_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_vpcs,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_subnets_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_subnets, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_subnets_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_subnets,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_instances_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_instances, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_instances_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_instances,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_images_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_images, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_images_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_images,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def deregister_image_response(image_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:image_id])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :deregister_image, image_id, examples)
      AwsSdk.Sandbox.apply_func(func, [image_id, opts], examples)
    end

    def set_deregister_image_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :deregister_image,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_snapshot_response(snapshot_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:snapshot_id])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_snapshot, snapshot_id, examples)
      AwsSdk.Sandbox.apply_func(func, [snapshot_id, opts], examples)
    end

    def set_delete_snapshot_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_snapshot,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_tags_response(resource_ids, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:resource_ids])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :create_tags,
          List.first(resource_ids) || "*",
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [resource_ids, opts], examples)
    end

    def set_create_tags_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_tags,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_tags_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_tags, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_tags_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_tags,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_launch_templates_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_launch_templates, "*", examples)

      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_launch_templates_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_launch_templates,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_launch_template_versions_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_launch_template_versions,
          "*",
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_launch_template_versions_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_launch_template_versions,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def terminate_instances_response(instance_ids, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_ids])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :terminate_instances, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [instance_ids, opts], examples)
    end

    def set_terminate_instances_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :terminate_instances,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_console_output_response(instance_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:instance_id])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :get_console_output, instance_id, examples)

      AwsSdk.Sandbox.apply_func(func, [instance_id, opts], examples)
    end

    def set_get_console_output_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_console_output,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_network_acls_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_network_acls, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_network_acls_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_network_acls,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_route_tables_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_route_tables, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_route_tables_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_route_tables,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
