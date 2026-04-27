defmodule AWS.S3.XMLBuilderTest do
  use ExUnit.Case, async: true

  alias AWS.S3.XMLBuilder

  @xmlns "http://s3.amazonaws.com/doc/2006-03-01/"

  describe "build_public_access_block/1" do
    test "defaults all four flags to true" do
      assert XMLBuilder.build_public_access_block() ===
               "<PublicAccessBlockConfiguration xmlns=\"#{@xmlns}\">" <>
                 "<BlockPublicAcls>true</BlockPublicAcls>" <>
                 "<IgnorePublicAcls>true</IgnorePublicAcls>" <>
                 "<BlockPublicPolicy>true</BlockPublicPolicy>" <>
                 "<RestrictPublicBuckets>true</RestrictPublicBuckets>" <>
                 "</PublicAccessBlockConfiguration>"
    end

    test "respects per-flag overrides" do
      xml =
        XMLBuilder.build_public_access_block(
          block_public_acls: false,
          ignore_public_acls: true,
          block_public_policy: false,
          restrict_public_buckets: true
        )

      assert xml =~ "<BlockPublicAcls>false</BlockPublicAcls>"
      assert xml =~ "<IgnorePublicAcls>true</IgnorePublicAcls>"
      assert xml =~ "<BlockPublicPolicy>false</BlockPublicPolicy>"
      assert xml =~ "<RestrictPublicBuckets>true</RestrictPublicBuckets>"
    end

    test "preserves the canonical element order" do
      xml = XMLBuilder.build_public_access_block()

      assert [_, acls, ignore, policy, restrict | _] =
               Regex.run(
                 ~r{<BlockPublicAcls>.*?</BlockPublicAcls>.*?<IgnorePublicAcls>.*?</IgnorePublicAcls>.*?<BlockPublicPolicy>.*?</BlockPublicPolicy>.*?<RestrictPublicBuckets>.*?</RestrictPublicBuckets>}s,
                 xml,
                 capture: :all
               ) ++ [nil, nil, nil, nil]

      _ = {acls, ignore, policy, restrict}
    end
  end

  describe "build_bucket_encryption/1" do
    test "defaults to AES256 with no KMS key and no bucket key" do
      assert XMLBuilder.build_bucket_encryption() ===
               "<ServerSideEncryptionConfiguration xmlns=\"#{@xmlns}\">" <>
                 "<Rule>" <>
                 "<ApplyServerSideEncryptionByDefault>" <>
                 "<SSEAlgorithm>AES256</SSEAlgorithm>" <>
                 "</ApplyServerSideEncryptionByDefault>" <>
                 "</Rule>" <>
                 "</ServerSideEncryptionConfiguration>"
    end

    test "includes KMSMasterKeyID when provided" do
      xml =
        XMLBuilder.build_bucket_encryption(
          sse_algorithm: "aws:kms",
          kms_master_key_id: "arn:aws:kms:us-east-1:111122223333:key/abcd"
        )

      assert xml =~ "<SSEAlgorithm>aws:kms</SSEAlgorithm>"
      assert xml =~ "<KMSMasterKeyID>arn:aws:kms:us-east-1:111122223333:key/abcd</KMSMasterKeyID>"
    end

    test "includes BucketKeyEnabled when set to true" do
      xml = XMLBuilder.build_bucket_encryption(bucket_key_enabled: true)
      assert xml =~ "<BucketKeyEnabled>true</BucketKeyEnabled>"
    end

    test "includes BucketKeyEnabled when set to false" do
      xml = XMLBuilder.build_bucket_encryption(bucket_key_enabled: false)
      assert xml =~ "<BucketKeyEnabled>false</BucketKeyEnabled>"
    end

    test "omits BucketKeyEnabled when unset" do
      refute XMLBuilder.build_bucket_encryption() =~ "BucketKeyEnabled"
    end

    test "places BucketKeyEnabled outside ApplyServerSideEncryptionByDefault" do
      xml = XMLBuilder.build_bucket_encryption(bucket_key_enabled: true)

      assert xml =~
               ~r{</ApplyServerSideEncryptionByDefault><BucketKeyEnabled>true</BucketKeyEnabled></Rule>}
    end
  end

  describe "build_lifecycle_configuration/1" do
    test "wraps an empty rule list in the configuration envelope" do
      assert XMLBuilder.build_lifecycle_configuration([]) ===
               "<LifecycleConfiguration xmlns=\"#{@xmlns}\"></LifecycleConfiguration>"
    end

    test "builds a prefix-filter expiration rule" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{id: "expire-logs", filter: %{prefix: "logs/"}, expiration: %{days: 30}}
        ])

      assert xml ===
               "<LifecycleConfiguration xmlns=\"#{@xmlns}\">" <>
                 "<Rule>" <>
                 "<ID>expire-logs</ID>" <>
                 "<Filter><Prefix>logs/</Prefix></Filter>" <>
                 "<Status>Enabled</Status>" <>
                 "<Expiration><Days>30</Days></Expiration>" <>
                 "</Rule>" <>
                 "</LifecycleConfiguration>"
    end

    test "defaults rule status to Enabled" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{id: "r", filter: %{}, expiration: %{days: 1}}
        ])

      assert xml =~ "<Status>Enabled</Status>"
    end

    test "respects an explicit Disabled status" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{id: "r", status: "Disabled", filter: %{}, expiration: %{days: 1}}
        ])

      assert xml =~ "<Status>Disabled</Status>"
    end

    test "emits an empty Filter element when no filter is given" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{id: "r", filter: %{}, expiration: %{days: 1}}
        ])

      assert xml =~ "<Filter></Filter>"
    end

    test "supports a single tag filter" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{id: "r", filter: %{tag: %{key: "stage", value: "tmp"}}, expiration: %{days: 1}}
        ])

      assert xml =~
               "<Filter><Tag><Key>stage</Key><Value>tmp</Value></Tag></Filter>"
    end

    test "supports object size filters" do
      gt =
        XMLBuilder.build_lifecycle_configuration([
          %{id: "r", filter: %{object_size_greater_than: 1024}, expiration: %{days: 1}}
        ])

      lt =
        XMLBuilder.build_lifecycle_configuration([
          %{id: "r", filter: %{object_size_less_than: 1_000_000}, expiration: %{days: 1}}
        ])

      assert gt =~ "<Filter><ObjectSizeGreaterThan>1024</ObjectSizeGreaterThan></Filter>"
      assert lt =~ "<Filter><ObjectSizeLessThan>1000000</ObjectSizeLessThan></Filter>"
    end

    test "supports an And filter combining prefix, sizes, and multiple tags" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{
            id: "r",
            filter: %{
              and: %{
                prefix: "logs/",
                object_size_greater_than: 1024,
                object_size_less_than: 1_000_000,
                tags: [%{key: "stage", value: "tmp"}, %{key: "team", value: "platform"}]
              }
            },
            expiration: %{days: 30}
          }
        ])

      assert xml =~
               "<Filter><And>" <>
                 "<Prefix>logs/</Prefix>" <>
                 "<ObjectSizeGreaterThan>1024</ObjectSizeGreaterThan>" <>
                 "<ObjectSizeLessThan>1000000</ObjectSizeLessThan>" <>
                 "<Tag><Key>stage</Key><Value>tmp</Value></Tag>" <>
                 "<Tag><Key>team</Key><Value>platform</Value></Tag>" <>
                 "</And></Filter>"
    end

    test "supports date-based expirations" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{id: "r", filter: %{}, expiration: %{date: "2026-01-01T00:00:00.000Z"}}
        ])

      assert xml =~ "<Expiration><Date>2026-01-01T00:00:00.000Z</Date></Expiration>"
    end

    test "supports ExpiredObjectDeleteMarker" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{id: "r", filter: %{}, expiration: %{expired_object_delete_marker: true}}
        ])

      assert xml =~
               "<Expiration><ExpiredObjectDeleteMarker>true</ExpiredObjectDeleteMarker></Expiration>"
    end

    test "supports transitions and abort multipart in a single rule" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{
            id: "tier-and-cleanup",
            filter: %{},
            transitions: [
              %{days: 30, storage_class: "STANDARD_IA"},
              %{days: 90, storage_class: "GLACIER"}
            ],
            abort_incomplete_multipart_upload: %{days_after_initiation: 7}
          }
        ])

      assert xml =~
               "<Transition><Days>30</Days><StorageClass>STANDARD_IA</StorageClass></Transition>"

      assert xml =~
               "<Transition><Days>90</Days><StorageClass>GLACIER</StorageClass></Transition>"

      assert xml =~
               "<AbortIncompleteMultipartUpload><DaysAfterInitiation>7</DaysAfterInitiation></AbortIncompleteMultipartUpload>"
    end

    test "supports noncurrent version expiration and transitions" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{
            id: "noncurrent",
            filter: %{},
            noncurrent_version_expiration: %{
              noncurrent_days: 60,
              newer_noncurrent_versions: 5
            },
            noncurrent_version_transitions: [
              %{noncurrent_days: 30, storage_class: "GLACIER"}
            ]
          }
        ])

      assert xml =~
               "<NoncurrentVersionExpiration>" <>
                 "<NoncurrentDays>60</NoncurrentDays>" <>
                 "<NewerNoncurrentVersions>5</NewerNoncurrentVersions>" <>
                 "</NoncurrentVersionExpiration>"

      assert xml =~
               "<NoncurrentVersionTransition>" <>
                 "<NoncurrentDays>30</NoncurrentDays>" <>
                 "<StorageClass>GLACIER</StorageClass>" <>
                 "</NoncurrentVersionTransition>"
    end

    test "raises when a rule is missing the required :id" do
      assert_raise KeyError, fn ->
        XMLBuilder.build_lifecycle_configuration([%{filter: %{}, expiration: %{days: 1}}])
      end
    end

    test "concatenates multiple rules in order" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{id: "first", filter: %{prefix: "a/"}, expiration: %{days: 1}},
          %{id: "second", filter: %{prefix: "b/"}, expiration: %{days: 2}}
        ])

      assert [first_pos, second_pos] =
               [
                 Regex.run(~r/<ID>first<\/ID>/, xml, return: :index),
                 Regex.run(~r/<ID>second<\/ID>/, xml, return: :index)
               ]
               |> Enum.map(fn [{pos, _}] -> pos end)

      assert first_pos < second_pos
    end

    test "escapes XML-significant characters in IDs and tag values" do
      xml =
        XMLBuilder.build_lifecycle_configuration([
          %{
            id: "a&b<c>",
            filter: %{tag: %{key: "k\"", value: "v'"}},
            expiration: %{days: 1}
          }
        ])

      assert xml =~ "<ID>a&amp;b&lt;c&gt;</ID>"
      assert xml =~ "<Key>k&quot;</Key>"
      assert xml =~ "<Value>v&apos;</Value>"
    end
  end
end
