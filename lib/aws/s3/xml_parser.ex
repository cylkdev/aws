defmodule AWS.S3.XMLParser do
  @moduledoc false

  import SweetXml, only: [sigil_x: 2, xpath: 2, xpath: 3]

  def parse_copy_object_result(xml) do
    doc = SweetXml.parse(xml)

    case embedded_error(doc) do
      nil ->
        %{
          etag: xpath(doc, ~x"//ETag/text()"s),
          last_modified: xpath(doc, ~x"//LastModified/text()"s),
          checksum_crc32: xpath(doc, ~x"//CopyObjectResult/ChecksumCRC32/text()"so),
          checksum_crc32c: xpath(doc, ~x"//CopyObjectResult/ChecksumCRC32C/text()"so),
          checksum_crc64nvme: xpath(doc, ~x"//CopyObjectResult/ChecksumCRC64NVME/text()"so),
          checksum_sha1: xpath(doc, ~x"//CopyObjectResult/ChecksumSHA1/text()"so),
          checksum_sha256: xpath(doc, ~x"//CopyObjectResult/ChecksumSHA256/text()"so),
          checksum_sha512: xpath(doc, ~x"//CopyObjectResult/ChecksumSHA512/text()"so),
          checksum_md5: xpath(doc, ~x"//CopyObjectResult/ChecksumMD5/text()"so),
          checksum_xxhash64: xpath(doc, ~x"//CopyObjectResult/ChecksumXXHASH64/text()"so),
          checksum_xxhash3: xpath(doc, ~x"//CopyObjectResult/ChecksumXXHASH3/text()"so),
          checksum_xxhash128: xpath(doc, ~x"//CopyObjectResult/ChecksumXXHASH128/text()"so),
          checksum_type: xpath(doc, ~x"//CopyObjectResult/ChecksumType/text()"so)
        }

      error ->
        {:error, error}
    end
  end

  @doc """
  Parses S3 notification configuration XML and checks for EventBridge status.

  Returns a map with `:event_bridge_enabled` (boolean) and `:raw_xml` (original XML).
  """
  @spec parse_notification_configuration(xml :: binary()) :: map()
  def parse_notification_configuration(xml) do
    doc = SweetXml.parse(xml)
    event_bridge_enabled = xpath(doc, ~x"//EventBridgeConfiguration"o) !== nil

    %{
      event_bridge_enabled: event_bridge_enabled,
      raw_xml: xml,
      topic_configurations:
        xpath(doc, ~x"//NotificationConfiguration/TopicConfiguration"l,
          id: ~x"./Id/text()"so,
          topic: ~x"./Topic/text()"so,
          # The wire element is the singular `Event`, repeated.
          events: ~x"./Event/text()"sl,
          filter_rules: [
            ~x"./Filter/S3Key/FilterRule"l,
            name: ~x"./Name/text()"so,
            value: ~x"./Value/text()"so
          ]
        ),
      queue_configurations:
        xpath(doc, ~x"//NotificationConfiguration/QueueConfiguration"l,
          id: ~x"./Id/text()"so,
          queue: ~x"./Queue/text()"so,
          events: ~x"./Event/text()"sl,
          filter_rules: [
            ~x"./Filter/S3Key/FilterRule"l,
            name: ~x"./Name/text()"so,
            value: ~x"./Value/text()"so
          ]
        ),
      # The wire elements are `CloudFunctionConfiguration` / `CloudFunction`;
      # `LambdaFunctionConfiguration` is the model name, not the XML name.
      cloud_function_configurations:
        xpath(doc, ~x"//NotificationConfiguration/CloudFunctionConfiguration"l,
          id: ~x"./Id/text()"so,
          cloud_function: ~x"./CloudFunction/text()"so,
          events: ~x"./Event/text()"sl,
          filter_rules: [
            ~x"./Filter/S3Key/FilterRule"l,
            name: ~x"./Name/text()"so,
            value: ~x"./Value/text()"so
          ]
        )
    }
  end

  @doc """
  Parses a `ListAllMyBucketsResult` XML response.

  Returns `%{buckets: [...], owner: %{id, display_name}}`.
  """
  def parse_list_buckets(xml) do
    doc = SweetXml.parse(xml)

    %{
      buckets:
        xpath(doc, ~x"//Buckets/Bucket"l,
          name: ~x"./Name/text()"s,
          creation_date: ~x"./CreationDate/text()"s,
          bucket_region: ~x"./BucketRegion/text()"so,
          bucket_arn: ~x"./BucketArn/text()"so
        ),
      owner: %{
        id: xpath(doc, ~x"//Owner/ID/text()"s),
        display_name: xpath(doc, ~x"//Owner/DisplayName/text()"s)
      },
      continuation_token: xpath(doc, ~x"//ListAllMyBucketsResult/ContinuationToken/text()"so),
      prefix: xpath(doc, ~x"//ListAllMyBucketsResult/Prefix/text()"so)
    }
  end

  @doc """
  Parses a `ListBucketResult` (v2) XML response.

  Returns `%{contents: [...], is_truncated, key_count, max_keys, name, prefix,
  continuation_token, next_continuation_token}`.
  """
  def parse_list_objects(xml) do
    doc = SweetXml.parse(xml)

    %{
      name: xpath(doc, ~x"//ListBucketResult/Name/text()"s),
      prefix: xpath(doc, ~x"//ListBucketResult/Prefix/text()"s),
      key_count: xpath(doc, ~x"//ListBucketResult/KeyCount/text()"s),
      max_keys: xpath(doc, ~x"//ListBucketResult/MaxKeys/text()"s),
      is_truncated: to_bool(xpath(doc, ~x"//ListBucketResult/IsTruncated/text()"s)),
      continuation_token: xpath(doc, ~x"//ListBucketResult/ContinuationToken/text()"so),
      next_continuation_token: xpath(doc, ~x"//ListBucketResult/NextContinuationToken/text()"so),
      delimiter: xpath(doc, ~x"//ListBucketResult/Delimiter/text()"so),
      encoding_type: xpath(doc, ~x"//ListBucketResult/EncodingType/text()"so),
      start_after: xpath(doc, ~x"//ListBucketResult/StartAfter/text()"so),
      # `CommonPrefixes` repeats inline rather than sitting in a wrapper.
      common_prefixes: xpath(doc, ~x"//ListBucketResult/CommonPrefixes/Prefix/text()"sl),
      contents:
        xpath(doc, ~x"//Contents"l,
          key: ~x"./Key/text()"s,
          last_modified: ~x"./LastModified/text()"s,
          etag: ~x"./ETag/text()"s,
          size: ~x"./Size/text()"s,
          storage_class: ~x"./StorageClass/text()"s,
          # On `Object` this is an array, unlike the singular String of the
          # same name on `ListPartsResult`.
          checksum_algorithm: ~x"./ChecksumAlgorithm/text()"sl,
          checksum_type: ~x"./ChecksumType/text()"so,
          owner: [
            ~x"./Owner"o,
            id: ~x"./ID/text()"so,
            display_name: ~x"./DisplayName/text()"so
          ],
          restore_status: [
            ~x"./RestoreStatus"o,
            is_restore_in_progress: ~x"./IsRestoreInProgress/text()"so,
            restore_expiry_date: ~x"./RestoreExpiryDate/text()"so
          ]
        )
    }
  end

  @doc """
  Parses an `InitiateMultipartUploadResult` XML response.

  Returns `%{bucket, key, upload_id}`.
  """
  def parse_initiate_multipart(xml) do
    doc = SweetXml.parse(xml)

    %{
      bucket: xpath(doc, ~x"//Bucket/text()"s),
      key: xpath(doc, ~x"//Key/text()"s),
      upload_id: xpath(doc, ~x"//UploadId/text()"s)
    }
  end

  @doc """
  Parses a `ListPartsResult` XML response.

  Returns `%{parts: [...], is_truncated, part_number_marker, next_part_number_marker,
  max_parts, bucket, key, upload_id}`.
  """
  def parse_list_parts(xml) do
    doc = SweetXml.parse(xml)

    %{
      bucket: xpath(doc, ~x"//ListPartsResult/Bucket/text()"s),
      key: xpath(doc, ~x"//ListPartsResult/Key/text()"s),
      upload_id: xpath(doc, ~x"//ListPartsResult/UploadId/text()"s),
      part_number_marker: xpath(doc, ~x"//ListPartsResult/PartNumberMarker/text()"so),
      next_part_number_marker: xpath(doc, ~x"//ListPartsResult/NextPartNumberMarker/text()"so),
      max_parts: xpath(doc, ~x"//ListPartsResult/MaxParts/text()"s),
      is_truncated: to_bool(xpath(doc, ~x"//ListPartsResult/IsTruncated/text()"s)),
      storage_class: xpath(doc, ~x"//ListPartsResult/StorageClass/text()"so),
      # Singular String here, unlike the array on an Object in ListObjectsV2.
      checksum_algorithm: xpath(doc, ~x"//ListPartsResult/ChecksumAlgorithm/text()"so),
      checksum_type: xpath(doc, ~x"//ListPartsResult/ChecksumType/text()"so),
      initiator: %{
        id: xpath(doc, ~x"//ListPartsResult/Initiator/ID/text()"so),
        display_name: xpath(doc, ~x"//ListPartsResult/Initiator/DisplayName/text()"so)
      },
      owner: %{
        id: xpath(doc, ~x"//ListPartsResult/Owner/ID/text()"so),
        display_name: xpath(doc, ~x"//ListPartsResult/Owner/DisplayName/text()"so)
      },
      parts:
        xpath(doc, ~x"//Part"l,
          part_number: ~x"./PartNumber/text()"s,
          last_modified: ~x"./LastModified/text()"s,
          etag: ~x"./ETag/text()"s,
          size: ~x"./Size/text()"s,
          checksum_crc32: ~x"./ChecksumCRC32/text()"so,
          checksum_crc32c: ~x"./ChecksumCRC32C/text()"so,
          checksum_crc64nvme: ~x"./ChecksumCRC64NVME/text()"so,
          checksum_sha1: ~x"./ChecksumSHA1/text()"so,
          checksum_sha256: ~x"./ChecksumSHA256/text()"so,
          checksum_sha512: ~x"./ChecksumSHA512/text()"so,
          checksum_md5: ~x"./ChecksumMD5/text()"so,
          checksum_xxhash64: ~x"./ChecksumXXHASH64/text()"so,
          checksum_xxhash3: ~x"./ChecksumXXHASH3/text()"so,
          checksum_xxhash128: ~x"./ChecksumXXHASH128/text()"so
        )
    }
  end

  @doc """
  Parses a `CopyPartResult` XML response.

  Returns `%{etag, last_modified}`.
  """
  def parse_copy_part(xml) do
    doc = SweetXml.parse(xml)

    %{
      etag: xpath(doc, ~x"//ETag/text()"s),
      last_modified: xpath(doc, ~x"//LastModified/text()"s),
      checksum_crc32: xpath(doc, ~x"//CopyPartResult/ChecksumCRC32/text()"so),
      checksum_crc32c: xpath(doc, ~x"//CopyPartResult/ChecksumCRC32C/text()"so),
      checksum_crc64nvme: xpath(doc, ~x"//CopyPartResult/ChecksumCRC64NVME/text()"so),
      checksum_sha1: xpath(doc, ~x"//CopyPartResult/ChecksumSHA1/text()"so),
      checksum_sha256: xpath(doc, ~x"//CopyPartResult/ChecksumSHA256/text()"so),
      checksum_sha512: xpath(doc, ~x"//CopyPartResult/ChecksumSHA512/text()"so),
      checksum_md5: xpath(doc, ~x"//CopyPartResult/ChecksumMD5/text()"so),
      checksum_xxhash64: xpath(doc, ~x"//CopyPartResult/ChecksumXXHASH64/text()"so),
      checksum_xxhash3: xpath(doc, ~x"//CopyPartResult/ChecksumXXHASH3/text()"so),
      checksum_xxhash128: xpath(doc, ~x"//CopyPartResult/ChecksumXXHASH128/text()"so)
    }
  end

  @doc """
  Parses a `CompleteMultipartUploadResult` XML response.

  Returns `%{location, bucket, key, etag}`.
  """
  def parse_complete_multipart(xml) do
    doc = SweetXml.parse(xml)

    case embedded_error(doc) do
      nil ->
        %{
          location: xpath(doc, ~x"//Location/text()"s),
          bucket: xpath(doc, ~x"//Bucket/text()"s),
          key: xpath(doc, ~x"//Key/text()"s),
          etag: xpath(doc, ~x"//ETag/text()"s),
          checksum_crc32: xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumCRC32/text()"so),
          checksum_crc32c:
            xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumCRC32C/text()"so),
          checksum_crc64nvme:
            xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumCRC64NVME/text()"so),
          checksum_sha1: xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumSHA1/text()"so),
          checksum_sha256:
            xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumSHA256/text()"so),
          checksum_sha512:
            xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumSHA512/text()"so),
          checksum_md5: xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumMD5/text()"so),
          checksum_xxhash64:
            xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumXXHASH64/text()"so),
          checksum_xxhash3:
            xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumXXHASH3/text()"so),
          checksum_xxhash128:
            xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumXXHASH128/text()"so),
          checksum_type: xpath(doc, ~x"//CompleteMultipartUploadResult/ChecksumType/text()"so)
        }

      error ->
        {:error, error}
    end
  end

  # CopyObject and CompleteMultipartUpload can answer 200 OK with an <Error>
  # body -- AWS documents this explicitly and tells callers to parse the
  # contents. Without this the failed upload returned
  # `{:ok, %{location: "", bucket: "", key: "", etag: ""}}`.
  defp embedded_error(doc) do
    case xpath(doc, ~x"//Error/Code/text()"s) do
      "" ->
        nil

      code ->
        ErrorMessage.internal_server_error("s3 returned an error in a 200 response", %{
          code: code,
          message: xpath(doc, ~x"//Error/Message/text()"s),
          request_id: xpath(doc, ~x"//Error/RequestId/text()"s)
        })
    end
  end

  # S3 returns IsTruncated as "true"/"false" text.
  defp to_bool("true"), do: true
  defp to_bool("false"), do: false
  defp to_bool(_), do: false
end
