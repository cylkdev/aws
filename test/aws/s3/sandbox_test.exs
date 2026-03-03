defmodule AWS.S3.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.S3
  alias AWS.S3.Sandbox

  @bucket "test-bucket"
  @object "test-object"
  @sandbox_opts [sandbox: [enabled: true, mode: :inline]]

  describe "list_buckets/1" do
    test "returns mocked bucket list" do
      Sandbox.set_list_buckets_responses([
        fn ->
          {:ok,
           [
             %{
               name: "test-bucket",
               creation_date: ~U[2025-09-30 20:48:01.000Z]
             }
           ]}
        end
      ])

      assert {:ok,
              [
                %{
                  name: "test-bucket",
                  creation_date: ~U[2025-09-30 20:48:01.000Z]
                }
              ]} = S3.list_buckets(@sandbox_opts)
    end
  end

  describe "create_bucket/2" do
    test "returns mocked creation response" do
      Sandbox.set_create_bucket_responses([
        {@bucket,
         fn ->
           {:ok, %{location: "/test-bucket", x_amz_request_id: "req-123"}}
         end}
      ])

      assert {:ok, %{location: "/test-bucket", x_amz_request_id: "req-123"}} =
               S3.create_bucket(@bucket, @sandbox_opts)
    end
  end

  describe "put_object/4" do
    test "returns mocked headers" do
      Sandbox.set_put_object_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              etag: "9725d5a30c6130db8e169c4d9560ded7",
              date: "Fri, 19 Sep 2025 18:40:13 GMT"
            }}
         end}
      ])

      assert {:ok,
              %{
                etag: "9725d5a30c6130db8e169c4d9560ded7",
                date: "Fri, 19 Sep 2025 18:40:13 GMT"
              }} = S3.put_object(@bucket, @object, "test-content", @sandbox_opts)
    end

    test "supports regex bucket matching" do
      Sandbox.set_put_object_responses([
        {~r|.*|,
         fn ->
           {:ok, %{etag: "abc123"}}
         end}
      ])

      assert {:ok, %{etag: "abc123"}} =
               S3.put_object("any-bucket", @object, "content", @sandbox_opts)
    end
  end

  describe "head_object/3" do
    test "returns mocked object metadata" do
      Sandbox.set_head_object_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              content_length: 123,
              content_type: "image/png",
              etag: "abcdef1234567890"
            }}
         end}
      ])

      assert {:ok,
              %{
                content_length: 123,
                content_type: "image/png",
                etag: "abcdef1234567890"
              }} = S3.head_object(@bucket, @object, @sandbox_opts)
    end

    test "returns error when object does not exist" do
      Sandbox.set_head_object_responses([
        {@bucket,
         fn ->
           {:error,
            %ErrorMessage{
              code: :not_found,
              message: "object not found",
              details: %{bucket: @bucket, key: "nonexistent.txt"}
            }}
         end}
      ])

      assert {:error,
              %ErrorMessage{
                code: :not_found,
                message: "object not found"
              }} = S3.head_object(@bucket, "nonexistent.txt", @sandbox_opts)
    end
  end

  describe "delete_object/3" do
    test "returns mocked response" do
      Sandbox.set_delete_object_responses([
        {@bucket,
         fn ->
           {:ok, ""}
         end}
      ])

      assert {:ok, ""} = S3.delete_object(@bucket, @object, @sandbox_opts)
    end
  end

  describe "get_object/3" do
    test "returns mocked object body" do
      Sandbox.set_get_object_responses([
        {@bucket,
         fn key ->
           {:ok, "content for #{key}"}
         end}
      ])

      assert {:ok, "content for test-object"} =
               S3.get_object(@bucket, @object, @sandbox_opts)
    end
  end

  describe "list_objects/2" do
    test "returns mocked object list" do
      Sandbox.set_list_objects_responses([
        {@bucket,
         fn ->
           {:ok,
            [
              %{
                key: "hello_world.txt",
                size: 12,
                storage_class: "STANDARD",
                etag: "86fb269d190d2c85f6e0468ceca42a20"
              }
            ]}
         end}
      ])

      assert {:ok,
              [
                %{
                  key: "hello_world.txt",
                  size: 12,
                  storage_class: "STANDARD"
                }
              ]} = S3.list_objects(@bucket, @sandbox_opts)
    end
  end

  describe "copy_object/5" do
    test "returns mocked copy response" do
      Sandbox.set_copy_object_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              last_modified: ~U[2025-08-30 01:00:00.000000Z],
              etag: "etag"
            }}
         end}
      ])

      assert {:ok,
              %{
                last_modified: ~U[2025-08-30 01:00:00.000000Z],
                etag: "etag"
              }} = S3.copy_object(@bucket, @object, @bucket, @object, @sandbox_opts)
    end

    test "returns error when object does not exist" do
      Sandbox.set_copy_object_responses([
        {@bucket,
         fn ->
           {:error,
            %ErrorMessage{
              code: :not_found,
              message: "object not found"
            }}
         end}
      ])

      assert {:error, %ErrorMessage{code: :not_found}} =
               S3.copy_object(@bucket, @object, @bucket, "nonexistent", @sandbox_opts)
    end
  end

  describe "presign/4" do
    test "returns mocked presigned URL with variable arity" do
      Sandbox.set_presign_responses([
        {@bucket,
         fn :post, object ->
           %{
             key: object,
             url: "https://example.com/#{object}?signature=fake",
             expires_in: 60,
             expires_at: ~U[2025-08-30 01:00:00.000000Z]
           }
         end}
      ])

      assert %{
               key: @object,
               url: "https://example.com/test-object?signature=fake",
               expires_in: 60,
               expires_at: ~U[2025-08-30 01:00:00.000000Z]
             } = S3.presign(@bucket, :post, @object, @sandbox_opts)
    end
  end

  describe "presign_post/3" do
    test "returns mocked presigned POST config" do
      Sandbox.set_presign_post_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              fields: %{key: "test-object", policy: "base64policy"},
              url: "https://example.com",
              expires_in: 60,
              expires_at: ~U[2025-08-30 01:00:00.000000Z]
            }}
         end}
      ])

      assert {:ok,
              %{
                fields: %{key: "test-object"},
                url: "https://example.com",
                expires_in: 60
              }} = S3.presign_post(@bucket, @object, @sandbox_opts)
    end
  end

  describe "presign_part/5" do
    test "returns mocked presigned part URL" do
      Sandbox.set_presign_part_responses([
        {@bucket,
         fn ->
           %{
             key: "test-object",
             url: "https://example.com/test-object?uploadId=uid&partNumber=1",
             expires_in: 60,
             expires_at: ~U[2025-08-30 01:00:00.000000Z]
           }
         end}
      ])

      assert %{
               key: "test-object",
               url: url,
               expires_in: 60
             } = S3.presign_part(@bucket, @object, "upload-id", 1, @sandbox_opts)

      assert url =~ "example.com"
    end
  end

  describe "create_multipart_upload/3" do
    test "returns upload metadata" do
      Sandbox.set_create_multipart_upload_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              bucket: @bucket,
              key: @object,
              upload_id: "upload_id_123"
            }}
         end}
      ])

      assert {:ok, %{bucket: @bucket, key: @object, upload_id: "upload_id_123"}} =
               S3.create_multipart_upload(@bucket, @object, @sandbox_opts)
    end

    test "returns error on failure" do
      Sandbox.set_create_multipart_upload_responses([
        {@bucket,
         fn ->
           {:error,
            %ErrorMessage{
              code: :service_unavailable,
              message: "service temporarily unavailable"
            }}
         end}
      ])

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               S3.create_multipart_upload(@bucket, @object, @sandbox_opts)
    end
  end

  describe "abort_multipart_upload/4" do
    test "returns ok tuple on success" do
      Sandbox.set_abort_multipart_upload_responses([
        {@bucket,
         fn ->
           {:ok, %{date: "Fri, 18 Aug 2023 10:32:49 GMT"}}
         end}
      ])

      assert {:ok, %{date: "Fri, 18 Aug 2023 10:32:49 GMT"}} =
               S3.abort_multipart_upload(@bucket, @object, "upload_id_123", @sandbox_opts)
    end

    test "returns error on failure" do
      Sandbox.set_abort_multipart_upload_responses([
        {@bucket,
         fn ->
           {:error,
            %ErrorMessage{
              code: :service_unavailable,
              message: "service temporarily unavailable"
            }}
         end}
      ])

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               S3.abort_multipart_upload(@bucket, @object, "upload_id_123", @sandbox_opts)
    end
  end

  describe "upload_part/6" do
    test "returns ok on success" do
      Sandbox.set_upload_part_responses([
        {@bucket,
         fn ->
           {:ok, %{etag: "etag", content_length: 0}}
         end}
      ])

      assert {:ok, %{etag: "etag", content_length: 0}} =
               S3.upload_part(@bucket, @object, "upload_id", 1, "content", @sandbox_opts)
    end

    test "returns error on failure" do
      Sandbox.set_upload_part_responses([
        {@bucket,
         fn ->
           {:error,
            %ErrorMessage{
              code: :not_found,
              message: "object not found"
            }}
         end}
      ])

      assert {:error, %ErrorMessage{code: :not_found}} =
               S3.upload_part(@bucket, @object, "upload_id", 1, "content", @sandbox_opts)
    end
  end

  describe "list_parts/5" do
    test "returns list of parts on success" do
      Sandbox.set_list_parts_responses([
        {@bucket,
         fn ->
           {:ok, [%{part_number: 1, size: 5_247_794, etag: "etag_123"}]}
         end}
      ])

      assert {:ok, [%{part_number: 1, size: 5_247_794, etag: "etag_123"}]} =
               S3.list_parts(@bucket, @object, "upload_id_123", nil, @sandbox_opts)
    end

    test "returns error when upload not found" do
      Sandbox.set_list_parts_responses([
        {@bucket,
         fn ->
           {:error,
            %ErrorMessage{
              code: :not_found,
              message: "object not found"
            }}
         end}
      ])

      assert {:error, %ErrorMessage{code: :not_found}} =
               S3.list_parts(@bucket, @object, "upload_id", nil, @sandbox_opts)
    end
  end

  describe "copy_part/8" do
    test "returns ok on success" do
      Sandbox.set_copy_part_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              last_modified: ~U[2025-08-30 01:00:00.000000Z],
              etag: "etag_123"
            }}
         end}
      ])

      assert {:ok,
              %{
                last_modified: ~U[2025-08-30 01:00:00.000000Z],
                etag: "etag_123"
              }} =
               S3.copy_part(
                 @bucket,
                 "dest.txt",
                 @bucket,
                 @object,
                 "upload_id_123",
                 1,
                 0..99,
                 @sandbox_opts
               )
    end

    test "returns error on failure" do
      Sandbox.set_copy_part_responses([
        {@bucket,
         fn ->
           {:error,
            %ErrorMessage{code: :service_unavailable, message: "service temporarily unavailable"}}
         end}
      ])

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               S3.copy_part(
                 @bucket,
                 "dest.txt",
                 @bucket,
                 @object,
                 "upload_id_123",
                 2,
                 0..99,
                 @sandbox_opts
               )
    end
  end

  describe "copy_parts/7" do
    test "returns ok on success" do
      Sandbox.set_copy_parts_responses([
        {@bucket,
         fn ->
           {:ok, [{1, "etag_1"}, {2, "etag_2"}]}
         end}
      ])

      assert {:ok, [{1, "etag_1"}, {2, "etag_2"}]} =
               S3.copy_parts(
                 @bucket,
                 @object,
                 @bucket,
                 @object,
                 "upload_id",
                 123,
                 @sandbox_opts
               )
    end

    test "returns error on failure" do
      Sandbox.set_copy_parts_responses([
        {@bucket,
         fn ->
           {:error,
            %ErrorMessage{code: :service_unavailable, message: "service temporarily unavailable"}}
         end}
      ])

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               S3.copy_parts(
                 @bucket,
                 @object,
                 @bucket,
                 @object,
                 "upload_id",
                 123,
                 @sandbox_opts
               )
    end
  end

  describe "complete_multipart_upload/5" do
    test "returns file metadata on success" do
      Sandbox.set_complete_multipart_upload_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              location: "https://s3.amazonaws.com/test-bucket/test-object",
              bucket: @bucket,
              key: @object,
              etag: "final-etag"
            }}
         end}
      ])

      assert {:ok,
              %{
                location: "https://s3.amazonaws.com/test-bucket/test-object",
                bucket: @bucket,
                key: @object,
                etag: "final-etag"
              }} =
               S3.complete_multipart_upload(
                 @bucket,
                 @object,
                 "upload_id_123",
                 [{1, "etag_123"}],
                 @sandbox_opts
               )
    end

    test "returns error on failure" do
      Sandbox.set_complete_multipart_upload_responses([
        {@bucket,
         fn ->
           {:error,
            %ErrorMessage{
              code: :service_unavailable,
              message: "service temporarily unavailable"
            }}
         end}
      ])

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               S3.complete_multipart_upload(
                 @bucket,
                 @object,
                 "bad_upload_id",
                 [{1, "etag"}],
                 @sandbox_opts
               )
    end
  end
end
