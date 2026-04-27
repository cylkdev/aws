defmodule AWS.S3.XMLBuilder do
  @moduledoc """
  Builds the XML request bodies that S3 expects for write operations whose
  payload is an XML document: `PutPublicAccessBlock`, `PutBucketEncryption`,
  and `PutBucketLifecycleConfiguration`.

  Counterpart to `AWS.S3.XMLParser`, which extracts data from the XML
  responses S3 returns. Each builder is a pure function over Elixir data and
  returns a binary that can be asserted on directly in tests, independently
  of any HTTP transport.
  """

  @xmlns "http://s3.amazonaws.com/doc/2006-03-01/"

  @doc """
  Builds the `<PublicAccessBlockConfiguration>` XML body for
  `PutPublicAccessBlock`.

  All four flags default to `true` (the most restrictive setting).

  ## Options

    * `:block_public_acls` - Defaults to `true`.
    * `:ignore_public_acls` - Defaults to `true`.
    * `:block_public_policy` - Defaults to `true`.
    * `:restrict_public_buckets` - Defaults to `true`.
  """
  @spec build_public_access_block(opts :: keyword()) :: binary()
  def build_public_access_block(opts \\ []) do
    block_public_acls = Keyword.get(opts, :block_public_acls, true)
    ignore_public_acls = Keyword.get(opts, :ignore_public_acls, true)
    block_public_policy = Keyword.get(opts, :block_public_policy, true)
    restrict_public_buckets = Keyword.get(opts, :restrict_public_buckets, true)

    "<PublicAccessBlockConfiguration xmlns=\"#{@xmlns}\">" <>
      "<BlockPublicAcls>#{block_public_acls}</BlockPublicAcls>" <>
      "<IgnorePublicAcls>#{ignore_public_acls}</IgnorePublicAcls>" <>
      "<BlockPublicPolicy>#{block_public_policy}</BlockPublicPolicy>" <>
      "<RestrictPublicBuckets>#{restrict_public_buckets}</RestrictPublicBuckets>" <>
      "</PublicAccessBlockConfiguration>"
  end

  @doc """
  Builds the `<ServerSideEncryptionConfiguration>` XML body for
  `PutBucketEncryption`.

  ## Options

    * `:sse_algorithm` - One of `"AES256"` (default), `"aws:kms"`, or `"aws:kms:dsse"`.
    * `:kms_master_key_id` - Required when `:sse_algorithm` is a KMS variant.
    * `:bucket_key_enabled` - Optional boolean.
  """
  @spec build_bucket_encryption(opts :: keyword()) :: binary()
  def build_bucket_encryption(opts \\ []) do
    sse_algorithm = Keyword.get(opts, :sse_algorithm, "AES256")
    kms_master_key_id = opts[:kms_master_key_id]
    bucket_key_enabled = opts[:bucket_key_enabled]

    apply_default =
      "<SSEAlgorithm>#{sse_algorithm}</SSEAlgorithm>" <>
        kms_master_key_id_xml(kms_master_key_id)

    rule_inner =
      "<ApplyServerSideEncryptionByDefault>#{apply_default}</ApplyServerSideEncryptionByDefault>" <>
        bucket_key_enabled_xml(bucket_key_enabled)

    "<ServerSideEncryptionConfiguration xmlns=\"#{@xmlns}\"><Rule>#{rule_inner}</Rule></ServerSideEncryptionConfiguration>"
  end

  @doc """
  Builds the `<LifecycleConfiguration>` XML body for
  `PutBucketLifecycleConfiguration`.

  See `AWS.S3.put_bucket_lifecycle_configuration/3` for the supported rule
  shape.
  """
  @spec build_lifecycle_configuration(rules :: list(map())) :: binary()
  def build_lifecycle_configuration(rules) when is_list(rules) do
    rules_xml = Enum.map_join(rules, "", &lifecycle_rule_xml/1)
    "<LifecycleConfiguration xmlns=\"#{@xmlns}\">#{rules_xml}</LifecycleConfiguration>"
  end

  defp kms_master_key_id_xml(nil), do: ""
  defp kms_master_key_id_xml(id), do: "<KMSMasterKeyID>#{xml_escape(id)}</KMSMasterKeyID>"

  defp bucket_key_enabled_xml(nil), do: ""

  defp bucket_key_enabled_xml(value) when is_boolean(value),
    do: "<BucketKeyEnabled>#{value}</BucketKeyEnabled>"

  defp lifecycle_rule_xml(rule) do
    id = Map.fetch!(rule, :id)
    status = Map.get(rule, :status, "Enabled")
    filter = Map.get(rule, :filter, %{})

    parts =
      [
        "<ID>#{xml_escape(id)}</ID>",
        lifecycle_filter_xml(filter),
        "<Status>#{status}</Status>",
        expiration_xml(rule[:expiration]),
        transitions_xml(rule[:transitions]),
        noncurrent_version_expiration_xml(rule[:noncurrent_version_expiration]),
        noncurrent_version_transitions_xml(rule[:noncurrent_version_transitions]),
        abort_incomplete_multipart_xml(rule[:abort_incomplete_multipart_upload])
      ]
      |> Enum.reject(&(&1 === ""))
      |> Enum.join()

    "<Rule>#{parts}</Rule>"
  end

  defp lifecycle_filter_xml(filter) when map_size(filter) === 0, do: "<Filter></Filter>"

  defp lifecycle_filter_xml(%{prefix: prefix} = filter) when map_size(filter) === 1 do
    "<Filter><Prefix>#{xml_escape(prefix)}</Prefix></Filter>"
  end

  defp lifecycle_filter_xml(%{tag: %{key: k, value: v}} = filter) when map_size(filter) === 1 do
    "<Filter><Tag><Key>#{xml_escape(k)}</Key><Value>#{xml_escape(v)}</Value></Tag></Filter>"
  end

  defp lifecycle_filter_xml(%{object_size_greater_than: n} = filter)
       when map_size(filter) === 1 do
    "<Filter><ObjectSizeGreaterThan>#{n}</ObjectSizeGreaterThan></Filter>"
  end

  defp lifecycle_filter_xml(%{object_size_less_than: n} = filter)
       when map_size(filter) === 1 do
    "<Filter><ObjectSizeLessThan>#{n}</ObjectSizeLessThan></Filter>"
  end

  defp lifecycle_filter_xml(%{and: and_filter}) do
    "<Filter><And>#{and_filter_inner(and_filter)}</And></Filter>"
  end

  defp and_filter_inner(and_filter) do
    [
      and_filter_prefix(and_filter[:prefix]),
      and_filter_size(:object_size_greater_than, and_filter[:object_size_greater_than]),
      and_filter_size(:object_size_less_than, and_filter[:object_size_less_than]),
      and_filter_tags(and_filter[:tags] || [])
    ]
    |> Enum.reject(&(&1 === ""))
    |> Enum.join()
  end

  defp and_filter_prefix(nil), do: ""
  defp and_filter_prefix(prefix), do: "<Prefix>#{xml_escape(prefix)}</Prefix>"

  defp and_filter_size(_key, nil), do: ""

  defp and_filter_size(:object_size_greater_than, n),
    do: "<ObjectSizeGreaterThan>#{n}</ObjectSizeGreaterThan>"

  defp and_filter_size(:object_size_less_than, n),
    do: "<ObjectSizeLessThan>#{n}</ObjectSizeLessThan>"

  defp and_filter_tags(tags) do
    Enum.map_join(tags, "", fn %{key: k, value: v} ->
      "<Tag><Key>#{xml_escape(k)}</Key><Value>#{xml_escape(v)}</Value></Tag>"
    end)
  end

  defp expiration_xml(nil), do: ""

  defp expiration_xml(expiration) do
    inner =
      [
        days_xml(expiration[:days]),
        date_xml(expiration[:date]),
        expired_marker_xml(expiration[:expired_object_delete_marker])
      ]
      |> Enum.reject(&(&1 === ""))
      |> Enum.join()

    "<Expiration>#{inner}</Expiration>"
  end

  defp days_xml(nil), do: ""
  defp days_xml(n) when is_integer(n), do: "<Days>#{n}</Days>"

  defp date_xml(nil), do: ""
  defp date_xml(date), do: "<Date>#{date}</Date>"

  defp expired_marker_xml(nil), do: ""

  defp expired_marker_xml(value) when is_boolean(value),
    do: "<ExpiredObjectDeleteMarker>#{value}</ExpiredObjectDeleteMarker>"

  defp transitions_xml(nil), do: ""

  defp transitions_xml(transitions) when is_list(transitions) do
    Enum.map_join(transitions, "", fn t ->
      inner =
        [
          days_xml(t[:days]),
          date_xml(t[:date]),
          storage_class_xml(t[:storage_class])
        ]
        |> Enum.reject(&(&1 === ""))
        |> Enum.join()

      "<Transition>#{inner}</Transition>"
    end)
  end

  defp storage_class_xml(nil), do: ""
  defp storage_class_xml(class), do: "<StorageClass>#{class}</StorageClass>"

  defp noncurrent_version_expiration_xml(nil), do: ""

  defp noncurrent_version_expiration_xml(%{} = config) do
    inner =
      [
        noncurrent_days_xml(config[:noncurrent_days]),
        newer_versions_xml(config[:newer_noncurrent_versions])
      ]
      |> Enum.reject(&(&1 === ""))
      |> Enum.join()

    "<NoncurrentVersionExpiration>#{inner}</NoncurrentVersionExpiration>"
  end

  defp noncurrent_version_transitions_xml(nil), do: ""

  defp noncurrent_version_transitions_xml(transitions) when is_list(transitions) do
    Enum.map_join(transitions, "", fn t ->
      inner =
        [
          noncurrent_days_xml(t[:noncurrent_days]),
          newer_versions_xml(t[:newer_noncurrent_versions]),
          storage_class_xml(t[:storage_class])
        ]
        |> Enum.reject(&(&1 === ""))
        |> Enum.join()

      "<NoncurrentVersionTransition>#{inner}</NoncurrentVersionTransition>"
    end)
  end

  defp noncurrent_days_xml(nil), do: ""
  defp noncurrent_days_xml(n) when is_integer(n), do: "<NoncurrentDays>#{n}</NoncurrentDays>"

  defp newer_versions_xml(nil), do: ""

  defp newer_versions_xml(n) when is_integer(n),
    do: "<NewerNoncurrentVersions>#{n}</NewerNoncurrentVersions>"

  defp abort_incomplete_multipart_xml(nil), do: ""

  defp abort_incomplete_multipart_xml(%{days_after_initiation: n}) when is_integer(n) do
    "<AbortIncompleteMultipartUpload><DaysAfterInitiation>#{n}</DaysAfterInitiation></AbortIncompleteMultipartUpload>"
  end

  defp xml_escape(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp xml_escape(value), do: xml_escape(to_string(value))
end
