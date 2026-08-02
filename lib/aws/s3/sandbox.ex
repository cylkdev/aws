if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.S3.Sandbox do
    # Every operation keys on its bucket (the copy operations key on the
    # *destination* bucket), so registered keys are bucket names or regexes.
    use AWS.Sandbox,
      registry: :aws_s3_sandbox,
      operations: [
        list_buckets: [],
        create_bucket: [:bucket],
        delete_bucket: [:bucket],
        head_bucket: [:bucket],
        put_object: [:bucket, :key, :body],
        head_object: [:bucket, :key],
        delete_object: [:bucket, :key],
        get_object: [:bucket, :key],
        list_objects: [:bucket],
        copy_object: [:dest_bucket, :dest_key, :src_bucket, :src_key],
        presign: [:bucket, :http_method, :key],
        presign_post: [:bucket, :key],
        presign_part: [:bucket, :object, :upload_id, :part_number],
        create_multipart_upload: [:bucket, :key],
        abort_multipart_upload: [:bucket, :key, :upload_id],
        upload_part: [:bucket, :key, :upload_id, :part_number, :body],
        list_parts: [:bucket, :key, :upload_id, :part_number_marker],
        copy_part: [
          :dest_bucket,
          :dest_key,
          :src_bucket,
          :src_key,
          :upload_id,
          :part_number,
          :src_range
        ],
        copy_parts: [
          :dest_bucket,
          :dest_key,
          :src_bucket,
          :src_key,
          :upload_id,
          :content_length
        ],
        complete_multipart_upload: [:bucket, :key, :upload_id, :parts],
        enable_event_bridge: [:bucket],
        disable_event_bridge: [:bucket],
        get_notification_configuration: [:bucket],
        put_public_access_block: [:bucket],
        put_bucket_encryption: [:bucket],
        put_bucket_lifecycle_configuration: [:bucket, :rules]
      ]
  end
end
