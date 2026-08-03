if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.S3.Sandbox do
    @moduledoc false

    # Every operation keys on its bucket (the copy operations key on the
    # *destination* bucket), so registered keys are bucket names or regexes.

    @registry :aws_s3_sandbox

    def start_link, do: AWS.Sandbox.start_link(@registry)

    @spec disable_aws_s3_sandbox(map) :: :ok
    def disable_aws_s3_sandbox(_context), do: AWS.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AWS.Sandbox.disabled?(@registry, __MODULE__)

    def list_buckets_response(opts) do
      examples = AWS.Sandbox.doc_examples([])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_buckets, "*", examples)
      AWS.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_buckets_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_buckets,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_bucket_response(bucket, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_bucket, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, opts], examples)
    end

    def set_create_bucket_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_bucket,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_bucket_response(bucket, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_bucket, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, opts], examples)
    end

    def set_delete_bucket_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_bucket,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def head_bucket_response(bucket, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :head_bucket, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, opts], examples)
    end

    def set_head_bucket_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :head_bucket,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_object_response(bucket, key, body, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :key, :body])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :put_object, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, key, body, opts], examples)
    end

    def set_put_object_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_object,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def head_object_response(bucket, key, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :key])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :head_object, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, key, opts], examples)
    end

    def set_head_object_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :head_object,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_object_response(bucket, key, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :key])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :delete_object, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, key, opts], examples)
    end

    def set_delete_object_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_object,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_object_response(bucket, key, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :key])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :get_object, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, key, opts], examples)
    end

    def set_get_object_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_object,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_objects_response(bucket, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_objects, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, opts], examples)
    end

    def set_list_objects_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_objects,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def copy_object_response(dest_bucket, dest_key, src_bucket, src_key, opts) do
      examples = AWS.Sandbox.doc_examples([:dest_bucket, :dest_key, :src_bucket, :src_key])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :copy_object, dest_bucket, examples)
      AWS.Sandbox.apply_func(func, [dest_bucket, dest_key, src_bucket, src_key, opts], examples)
    end

    def set_copy_object_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :copy_object,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def presign_response(bucket, http_method, key, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :http_method, :key])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :presign, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, http_method, key, opts], examples)
    end

    def set_presign_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :presign,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def presign_post_response(bucket, key, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :key])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :presign_post, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, key, opts], examples)
    end

    def set_presign_post_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :presign_post,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def presign_part_response(bucket, object, upload_id, part_number, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :object, :upload_id, :part_number])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :presign_part, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, object, upload_id, part_number, opts], examples)
    end

    def set_presign_part_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :presign_part,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_multipart_upload_response(bucket, key, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :key])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :create_multipart_upload, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, key, opts], examples)
    end

    def set_create_multipart_upload_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_multipart_upload,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def abort_multipart_upload_response(bucket, key, upload_id, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :key, :upload_id])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :abort_multipart_upload, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, key, upload_id, opts], examples)
    end

    def set_abort_multipart_upload_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :abort_multipart_upload,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def upload_part_response(bucket, key, upload_id, part_number, body, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :key, :upload_id, :part_number, :body])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :upload_part, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, key, upload_id, part_number, body, opts], examples)
    end

    def set_upload_part_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :upload_part,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_parts_response(bucket, key, upload_id, part_number_marker, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :key, :upload_id, :part_number_marker])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :list_parts, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, key, upload_id, part_number_marker, opts], examples)
    end

    def set_list_parts_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_parts,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def copy_part_response(
          dest_bucket,
          dest_key,
          src_bucket,
          src_key,
          upload_id,
          part_number,
          src_range,
          opts
        ) do
      examples =
        AWS.Sandbox.doc_examples([
          :dest_bucket,
          :dest_key,
          :src_bucket,
          :src_key,
          :upload_id,
          :part_number,
          :src_range
        ])

      func = AWS.Sandbox.find!(@registry, __MODULE__, :copy_part, dest_bucket, examples)

      AWS.Sandbox.apply_func(
        func,
        [dest_bucket, dest_key, src_bucket, src_key, upload_id, part_number, src_range, opts],
        examples
      )
    end

    def set_copy_part_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :copy_part,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def copy_parts_response(
          dest_bucket,
          dest_key,
          src_bucket,
          src_key,
          upload_id,
          content_length,
          opts
        ) do
      examples =
        AWS.Sandbox.doc_examples([
          :dest_bucket,
          :dest_key,
          :src_bucket,
          :src_key,
          :upload_id,
          :content_length
        ])

      func = AWS.Sandbox.find!(@registry, __MODULE__, :copy_parts, dest_bucket, examples)

      AWS.Sandbox.apply_func(
        func,
        [dest_bucket, dest_key, src_bucket, src_key, upload_id, content_length, opts],
        examples
      )
    end

    def set_copy_parts_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :copy_parts,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def complete_multipart_upload_response(bucket, key, upload_id, parts, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :key, :upload_id, :parts])

      func =
        AWS.Sandbox.find!(@registry, __MODULE__, :complete_multipart_upload, bucket, examples)

      AWS.Sandbox.apply_func(func, [bucket, key, upload_id, parts, opts], examples)
    end

    def set_complete_multipart_upload_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :complete_multipart_upload,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def enable_event_bridge_response(bucket, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :enable_event_bridge, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, opts], examples)
    end

    def set_enable_event_bridge_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :enable_event_bridge,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def disable_event_bridge_response(bucket, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :disable_event_bridge, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, opts], examples)
    end

    def set_disable_event_bridge_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :disable_event_bridge,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def get_notification_configuration_response(bucket, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :get_notification_configuration,
          bucket,
          examples
        )

      AWS.Sandbox.apply_func(func, [bucket, opts], examples)
    end

    def set_get_notification_configuration_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :get_notification_configuration,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_public_access_block_response(bucket, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :put_public_access_block, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, opts], examples)
    end

    def set_put_public_access_block_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_public_access_block,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_bucket_encryption_response(bucket, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket])
      func = AWS.Sandbox.find!(@registry, __MODULE__, :put_bucket_encryption, bucket, examples)
      AWS.Sandbox.apply_func(func, [bucket, opts], examples)
    end

    def set_put_bucket_encryption_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_bucket_encryption,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end

    def put_bucket_lifecycle_configuration_response(bucket, rules, opts) do
      examples = AWS.Sandbox.doc_examples([:bucket, :rules])

      func =
        AWS.Sandbox.find!(
          @registry,
          __MODULE__,
          :put_bucket_lifecycle_configuration,
          bucket,
          examples
        )

      AWS.Sandbox.apply_func(func, [bucket, rules, opts], examples)
    end

    def set_put_bucket_lifecycle_configuration_responses(tuples) do
      AWS.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :put_bucket_lifecycle_configuration,
        AWS.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
