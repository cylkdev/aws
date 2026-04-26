defmodule AWS.S3.XMLParser do
  @moduledoc false

  import SweetXml, only: [sigil_x: 2, xpath: 2, xpath: 3]

  def parse_copy_object_result(xml) do
    doc = SweetXml.parse(xml)

    %{
      etag: xpath(doc, ~x"//ETag/text()"s),
      last_modified: xpath(doc, ~x"//LastModified/text()"s)
    }
  end

  @doc """
  Parses S3 notification configuration XML and checks for EventBridge status.

  Returns a map with `:event_bridge_enabled` (boolean) and `:raw_xml` (original XML).
  """
  @spec parse_notification_configuration(xml :: binary()) :: map()
  def parse_notification_configuration(xml) do
    doc = SweetXml.parse(xml)
    event_bridge_enabled = xpath(doc, ~x"//EventBridgeConfiguration"o) !== nil
    %{event_bridge_enabled: event_bridge_enabled, raw_xml: xml}
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
          creation_date: ~x"./CreationDate/text()"s
        ),
      owner: %{
        id: xpath(doc, ~x"//Owner/ID/text()"s),
        display_name: xpath(doc, ~x"//Owner/DisplayName/text()"s)
      }
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
      contents:
        xpath(doc, ~x"//Contents"l,
          key: ~x"./Key/text()"s,
          last_modified: ~x"./LastModified/text()"s,
          etag: ~x"./ETag/text()"s,
          size: ~x"./Size/text()"s,
          storage_class: ~x"./StorageClass/text()"s
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
      parts:
        xpath(doc, ~x"//Part"l,
          part_number: ~x"./PartNumber/text()"s,
          last_modified: ~x"./LastModified/text()"s,
          etag: ~x"./ETag/text()"s,
          size: ~x"./Size/text()"s
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
      last_modified: xpath(doc, ~x"//LastModified/text()"s)
    }
  end

  @doc """
  Parses a `CompleteMultipartUploadResult` XML response.

  Returns `%{location, bucket, key, etag}`.
  """
  def parse_complete_multipart(xml) do
    doc = SweetXml.parse(xml)

    %{
      location: xpath(doc, ~x"//Location/text()"s),
      bucket: xpath(doc, ~x"//Bucket/text()"s),
      key: xpath(doc, ~x"//Key/text()"s),
      etag: xpath(doc, ~x"//ETag/text()"s)
    }
  end

  # S3 returns IsTruncated as "true"/"false" text.
  defp to_bool("true"), do: true
  defp to_bool("false"), do: false
  defp to_bool(_), do: false
end
