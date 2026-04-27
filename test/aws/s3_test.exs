defmodule AWS.S3Test do
  use ExUnit.Case

  alias AWS.S3

  @sandbox_opts [sandbox: [enabled: true, mode: :local]]

  @bucket_name "aws-s3-test"

  describe "list_buckets/1" do
    test "returns a list of buckets" do
      bucket = random_bucket()

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      assert {:ok, buckets} = S3.list_buckets(@sandbox_opts)
      assert %{name: ^bucket, creation_date: _} = Enum.find(buckets, &(&1.name === bucket))
    end
  end

  describe "create_bucket/2" do
    test "creates a bucket and returns deserialized headers" do
      bucket = random_bucket()

      assert {:ok, %{location: _, x_amz_request_id: _, date: _}} =
               S3.create_bucket(bucket, @sandbox_opts)
    end

    test "can recreate a bucket after it is deleted" do
      bucket = random_bucket()

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.delete_bucket(bucket, @sandbox_opts)

      assert {:ok, %{location: _, x_amz_request_id: _, date: _}} =
               S3.create_bucket(bucket, @sandbox_opts)
    end
  end

  describe "put_object/4" do
    test "uploads an object and returns deserialized headers" do
      bucket = random_bucket()
      key = "put-object-#{random_id()}"
      body = "hello world"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      assert {:ok, %{etag: _, date: _}} = S3.put_object(bucket, key, body, @sandbox_opts)
    end

    test "uploaded object can be retrieved with get_object" do
      bucket = random_bucket()
      key = "put-object-#{random_id()}"
      body = "round trip content"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, key, body, @sandbox_opts)

      assert {:ok, ^body} = S3.get_object(bucket, key, @sandbox_opts)
    end
  end

  describe "head_object/3" do
    test "returns object metadata" do
      bucket = random_bucket()
      key = "head-object-#{random_id()}"
      body = "hello world"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, key, body, @sandbox_opts)

      assert {:ok, %{content_length: "11", content_type: "binary/octet-stream", etag: _}} =
               S3.head_object(bucket, key, @sandbox_opts)
    end

    test "returns an error when the object does not exist" do
      bucket = random_bucket()
      key = "nonexistent-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      assert {:error, %ErrorMessage{code: :not_found}} =
               S3.head_object(bucket, key, @sandbox_opts)
    end
  end

  describe "get_object/3" do
    test "returns the object body" do
      bucket = random_bucket()
      key = "get-object-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, key, "get object content", @sandbox_opts)

      assert {:ok, "get object content"} = S3.get_object(bucket, key, @sandbox_opts)
    end

    test "returns an error when the object does not exist" do
      bucket = random_bucket()
      key = "nonexistent-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      assert {:error, %ErrorMessage{code: :not_found}} =
               S3.get_object(bucket, key, @sandbox_opts)
    end
  end

  describe "delete_object/3" do
    test "deletes an object" do
      bucket = random_bucket()
      key = "delete-object-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, key, "to be deleted", @sandbox_opts)

      assert {:ok, ""} = S3.delete_object(bucket, key, @sandbox_opts)

      assert {:error, %ErrorMessage{code: :not_found}} =
               S3.head_object(bucket, key, @sandbox_opts)
    end
  end

  describe "list_objects/2" do
    test "returns a list of objects in a bucket" do
      bucket = random_bucket()
      key = "list-objects-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, key, "content", @sandbox_opts)

      assert {:ok, [%{key: ^key, size: _, storage_class: "STANDARD"} | _]} =
               S3.list_objects(bucket, @sandbox_opts)
    end
  end

  describe "presign/4" do
    test "returns a presigned URL map" do
      bucket = random_bucket()
      key = "presign-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      assert %{key: ^key, url: "http" <> _, expires_in: 60, expires_at: %DateTime{}} =
               S3.presign(bucket, :get, key, @sandbox_opts)
    end
  end

  describe "presign_post/3" do
    test "returns a presigned POST configuration" do
      bucket = random_bucket()
      key = "presign-post-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      assert {:ok,
              %{
                url: "http" <> _,
                expires_in: 60,
                expires_at: %DateTime{},
                fields: %{
                  key: _,
                  policy: _,
                  x_amz_algorithm: _,
                  x_amz_credential: _,
                  x_amz_date: _,
                  x_amz_signature: _
                }
              }} = S3.presign_post(bucket, key, @sandbox_opts)
    end
  end

  describe "create_multipart_upload/3" do
    test "initiates a multipart upload and returns upload metadata" do
      bucket = random_bucket()
      key = "multipart-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      assert {:ok, %{upload_id: _, key: ^key, bucket: ^bucket}} =
               S3.create_multipart_upload(bucket, key, @sandbox_opts)
    end
  end

  describe "abort_multipart_upload/4" do
    test "aborts a multipart upload" do
      bucket = random_bucket()
      key = "multipart-abort-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, key, @sandbox_opts)

      assert {:ok, %{date: _, x_amz_request_id: _}} =
               S3.abort_multipart_upload(bucket, key, mpu.upload_id, @sandbox_opts)
    end
  end

  describe "upload_part/6 and complete_multipart_upload/5" do
    test "uploads parts and completes a multipart upload" do
      bucket = random_bucket()
      key = "multipart-complete-#{random_id()}"
      part_body = String.duplicate("x", 5 * 1_024 * 1_024)

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, key, @sandbox_opts)

      assert {:ok, %{etag: etag, date: _}} =
               S3.upload_part(bucket, key, mpu.upload_id, 1, part_body, @sandbox_opts)

      assert {:ok, %{key: ^key, bucket: ^bucket, location: _, etag: _}} =
               S3.complete_multipart_upload(
                 bucket,
                 key,
                 mpu.upload_id,
                 [{1, etag}],
                 Keyword.merge(@sandbox_opts, max_size: :infinity)
               )
    end
  end

  describe "list_parts/5" do
    test "lists uploaded parts" do
      bucket = random_bucket()
      key = "multipart-list-#{random_id()}"
      part_body = String.duplicate("x", 5 * 1_024 * 1_024)

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, key, @sandbox_opts)

      assert {:ok, _} =
               S3.upload_part(bucket, key, mpu.upload_id, 1, part_body, @sandbox_opts)

      assert {:ok, %{parts: [%{part_number: "1", size: "5242880", etag: _}]}} =
               S3.list_parts(bucket, key, mpu.upload_id, nil, @sandbox_opts)
    end
  end

  describe "presign_part/5" do
    test "generates presigned URL for multipart upload part" do
      bucket = random_bucket()
      key = "presign-part-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, key, @sandbox_opts)

      assert %{key: ^key, url: url, expires_in: 60, expires_at: %DateTime{}} =
               S3.presign_part(bucket, key, mpu.upload_id, 1, @sandbox_opts)

      assert url =~ "http"
      assert url =~ "uploadId=#{mpu.upload_id}"
      assert url =~ "partNumber=1"
    end

    test "generates presigned URL with custom expiration" do
      bucket = random_bucket()
      key = "presign-part-custom-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, key, @sandbox_opts)

      opts = Keyword.merge(@sandbox_opts, expires_in: 300)

      assert %{key: ^key, url: _, expires_in: 300, expires_at: expires_at} =
               S3.presign_part(bucket, key, mpu.upload_id, 1, opts)

      assert DateTime.diff(expires_at, DateTime.utc_now()) in 295..305
    end
  end

  describe "copy_part/8" do
    test "copies a part from source to destination" do
      bucket = random_bucket()
      src_key = "copy-part-src-#{random_id()}"
      dest_key = "copy-part-dest-#{random_id()}"
      part_body = String.duplicate("x", 5 * 1_024 * 1_024)

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, src_key, part_body, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, dest_key, @sandbox_opts)

      assert {:ok, %{etag: etag, last_modified: _}} =
               S3.copy_part(
                 bucket,
                 dest_key,
                 bucket,
                 src_key,
                 mpu.upload_id,
                 1,
                 0..5_242_879,
                 @sandbox_opts
               )

      assert is_binary(etag)

      assert {:ok, %{parts: [%{part_number: "1", etag: ^etag}]}} =
               S3.list_parts(bucket, dest_key, mpu.upload_id, nil, @sandbox_opts)
    end

    test "returns error when copying from non-existent source" do
      bucket = random_bucket()
      src_key = "nonexistent-#{random_id()}"
      dest_key = "copy-part-dest-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, dest_key, @sandbox_opts)

      assert {:error, %ErrorMessage{code: :not_found}} =
               S3.copy_part(
                 bucket,
                 dest_key,
                 bucket,
                 src_key,
                 mpu.upload_id,
                 1,
                 0..5_242_879,
                 @sandbox_opts
               )
    end

    test "copies partial ranges from source object" do
      bucket = random_bucket()
      src_key = "copy-part-range-src-#{random_id()}"
      dest_key = "copy-part-range-dest-#{random_id()}"

      part_body =
        String.duplicate("a", 5 * 1_024 * 1_024) <> String.duplicate("b", 5 * 1_024 * 1_024)

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, src_key, part_body, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, dest_key, @sandbox_opts)

      assert {:ok, %{etag: etag1}} =
               S3.copy_part(
                 bucket,
                 dest_key,
                 bucket,
                 src_key,
                 mpu.upload_id,
                 1,
                 0..5_242_879,
                 @sandbox_opts
               )

      assert {:ok, %{etag: etag2}} =
               S3.copy_part(
                 bucket,
                 dest_key,
                 bucket,
                 src_key,
                 mpu.upload_id,
                 2,
                 5_242_880..10_485_759,
                 @sandbox_opts
               )

      assert etag1 !== etag2

      assert {:ok, %{parts: parts}} =
               S3.list_parts(bucket, dest_key, mpu.upload_id, nil, @sandbox_opts)

      assert length(parts) === 2
      assert Enum.find(parts, &(&1.part_number === "1"))
      assert Enum.find(parts, &(&1.part_number === "2"))
    end
  end

  describe "copy_parts/7" do
    test "copies multiple parts concurrently" do
      bucket = random_bucket()
      src_key = "copy-parts-src-#{random_id()}"
      dest_key = "copy-parts-dest-#{random_id()}"
      part_body = String.duplicate("x", 15 * 1_024 * 1_024)

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, src_key, part_body, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, dest_key, @sandbox_opts)

      opts =
        Keyword.merge(@sandbox_opts,
          content_byte_stream: [chunk_size: 5 * 1_024 * 1_024]
        )

      assert {:ok, parts} =
               S3.copy_parts(
                 bucket,
                 dest_key,
                 bucket,
                 src_key,
                 mpu.upload_id,
                 15 * 1_024 * 1_024,
                 opts
               )

      assert length(parts) === 3

      Enum.each(parts, fn {result, part_num} ->
        assert %{etag: etag} = result
        assert is_binary(etag)
        assert part_num in 1..3
      end)

      assert {:ok, %{parts: listed_parts}} =
               S3.list_parts(bucket, dest_key, mpu.upload_id, nil, @sandbox_opts)

      assert length(listed_parts) === 3
    end

    test "returns error when copying from non-existent source" do
      bucket = random_bucket()
      src_key = "nonexistent-#{random_id()}"
      dest_key = "copy-parts-dest-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, dest_key, @sandbox_opts)

      opts =
        Keyword.merge(@sandbox_opts,
          content_byte_stream: [chunk_size: 5 * 1_024 * 1_024]
        )

      assert {:error, errors} =
               S3.copy_parts(
                 bucket,
                 dest_key,
                 bucket,
                 src_key,
                 mpu.upload_id,
                 15 * 1_024 * 1_024,
                 opts
               )

      assert is_list(errors)
      assert errors !== []
    end

    test "respects max_concurrency option" do
      bucket = random_bucket()
      src_key = "copy-parts-concurrency-src-#{random_id()}"
      dest_key = "copy-parts-concurrency-dest-#{random_id()}"
      part_body = String.duplicate("x", 15 * 1_024 * 1_024)

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, src_key, part_body, @sandbox_opts)
      assert {:ok, mpu} = S3.create_multipart_upload(bucket, dest_key, @sandbox_opts)

      opts =
        Keyword.merge(@sandbox_opts,
          content_byte_stream: [chunk_size: 5 * 1_024 * 1_024, max_concurrency: 1]
        )

      assert {:ok, parts} =
               S3.copy_parts(
                 bucket,
                 dest_key,
                 bucket,
                 src_key,
                 mpu.upload_id,
                 15 * 1_024 * 1_024,
                 opts
               )

      assert length(parts) === 3
    end
  end

  describe "copy_object_multipart/5" do
    test "performs full multipart copy workflow" do
      bucket = random_bucket()
      src_key = "copy-multipart-src-#{random_id()}"
      dest_key = "copy-multipart-dest-#{random_id()}"
      part_body = String.duplicate("x", 15 * 1_024 * 1_024)

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, src_key, part_body, @sandbox_opts)

      opts =
        Keyword.merge(@sandbox_opts,
          content_byte_stream: [chunk_size: 5 * 1_024 * 1_024],
          max_size: :infinity
        )

      assert {:ok, %{location: _, bucket: ^bucket, key: ^dest_key, etag: _}} =
               S3.copy_object_multipart(bucket, dest_key, bucket, src_key, opts)

      assert {:ok, dest_meta} = S3.head_object(bucket, dest_key, @sandbox_opts)
      assert {:ok, src_meta} = S3.head_object(bucket, src_key, @sandbox_opts)

      assert dest_meta.content_length === src_meta.content_length
    end

    test "returns error when source object does not exist" do
      bucket = random_bucket()
      src_key = "nonexistent-#{random_id()}"
      dest_key = "copy-multipart-dest-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      opts =
        Keyword.merge(@sandbox_opts,
          content_byte_stream: [chunk_size: 5 * 1_024 * 1_024]
        )

      assert {:error, %ErrorMessage{code: :not_found}} =
               S3.copy_object_multipart(bucket, dest_key, bucket, src_key, opts)
    end

    test "returns error when source bucket does not exist" do
      src_bucket = random_bucket()
      dest_bucket = random_bucket()
      src_key = "copy-multipart-src-#{random_id()}"
      dest_key = "copy-multipart-dest-#{random_id()}"

      assert {:ok, _} = S3.create_bucket(dest_bucket, @sandbox_opts)

      opts =
        Keyword.merge(@sandbox_opts,
          content_byte_stream: [chunk_size: 5 * 1_024 * 1_024]
        )

      assert {:error, %ErrorMessage{code: :not_found}} =
               S3.copy_object_multipart(dest_bucket, dest_key, src_bucket, src_key, opts)
    end

    test "copies object across different buckets" do
      src_bucket = random_bucket()
      dest_bucket = random_bucket()
      src_key = "copy-multipart-cross-src-#{random_id()}"
      dest_key = "copy-multipart-cross-dest-#{random_id()}"
      part_body = String.duplicate("x", 15 * 1_024 * 1_024)

      assert {:ok, _} = S3.create_bucket(src_bucket, @sandbox_opts)
      assert {:ok, _} = S3.create_bucket(dest_bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(src_bucket, src_key, part_body, @sandbox_opts)

      opts =
        Keyword.merge(@sandbox_opts,
          content_byte_stream: [chunk_size: 5 * 1_024 * 1_024],
          max_size: :infinity
        )

      assert {:ok, %{bucket: ^dest_bucket, key: ^dest_key}} =
               S3.copy_object_multipart(dest_bucket, dest_key, src_bucket, src_key, opts)

      assert {:ok, _} = S3.head_object(src_bucket, src_key, @sandbox_opts)
      assert {:ok, _} = S3.head_object(dest_bucket, dest_key, @sandbox_opts)
    end
  end

  describe "copy_object/5" do
    test "copies an object to a new key" do
      bucket = random_bucket()
      src_key = "copy-src-#{random_id()}"
      dest_key = "copy-dest-#{random_id()}"
      body = "copy me"

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)
      assert {:ok, _} = S3.put_object(bucket, src_key, body, @sandbox_opts)

      assert {:ok, %{etag: _, last_modified: _}} =
               S3.copy_object(bucket, dest_key, bucket, src_key, @sandbox_opts)

      assert {:ok, "copy me"} = S3.get_object(bucket, dest_key, @sandbox_opts)
    end
  end

  describe "head_bucket/2" do
    test "returns deserialized headers when the bucket exists" do
      bucket = random_bucket()

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      assert {:ok, headers} = S3.head_bucket(bucket, @sandbox_opts)
      assert is_map(headers)
    end

    test "returns not_found when the bucket does not exist" do
      bucket = random_bucket()

      assert {:error, %ErrorMessage{code: :not_found}} = S3.head_bucket(bucket, @sandbox_opts)
    end
  end

  describe "put_public_access_block/2" do
    test "applies the default (most restrictive) configuration" do
      bucket = random_bucket()

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      assert {:ok, _} = S3.put_public_access_block(bucket, @sandbox_opts)
    end

    test "accepts overrides for individual flags" do
      bucket = random_bucket()

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      opts =
        Keyword.merge(@sandbox_opts,
          block_public_acls: false,
          ignore_public_acls: true,
          block_public_policy: false,
          restrict_public_buckets: true
        )

      assert {:ok, _} = S3.put_public_access_block(bucket, opts)
    end
  end

  describe "put_bucket_encryption/2" do
    test "sets default AES256 encryption" do
      bucket = random_bucket()

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      assert {:ok, _} = S3.put_bucket_encryption(bucket, @sandbox_opts)
    end

    test "accepts a bucket key enabled flag" do
      bucket = random_bucket()

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      opts = Keyword.merge(@sandbox_opts, bucket_key_enabled: true)

      assert {:ok, _} = S3.put_bucket_encryption(bucket, opts)
    end
  end

  describe "put_bucket_lifecycle_configuration/3" do
    test "applies a single expiration rule" do
      bucket = random_bucket()

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      rules = [
        %{
          id: "expire-logs",
          filter: %{prefix: "logs/"},
          expiration: %{days: 30}
        }
      ]

      assert {:ok, _} = S3.put_bucket_lifecycle_configuration(bucket, rules, @sandbox_opts)
    end

    test "applies a rule with transitions and abort multipart" do
      bucket = random_bucket()

      assert {:ok, _} = S3.create_bucket(bucket, @sandbox_opts)

      rules = [
        %{
          id: "tier-and-cleanup",
          filter: %{},
          status: "Enabled",
          transitions: [%{days: 30, storage_class: "STANDARD_IA"}],
          abort_incomplete_multipart_upload: %{days_after_initiation: 7}
        }
      ]

      assert {:ok, _} = S3.put_bucket_lifecycle_configuration(bucket, rules, @sandbox_opts)
    end
  end

  defp random_bucket do
    "#{@bucket_name}-#{random_id()}"
  end

  defp random_id do
    8
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower, padding: false)
  end
end
