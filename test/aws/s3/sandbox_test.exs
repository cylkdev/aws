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

  describe "object_exists?/3" do
    test "returns true when head_object succeeds" do
      Sandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{content_length: 1}} end}
      ])

      assert S3.object_exists?(@bucket, @object, @sandbox_opts)
    end

    test "returns false when head_object errors" do
      Sandbox.set_head_object_responses([
        {@bucket,
         fn ->
           {:error, %ErrorMessage{code: :not_found, message: "missing", details: %{}}}
         end}
      ])

      refute S3.object_exists?(@bucket, "missing.txt", @sandbox_opts)
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

  # S3 EventBridge notification functions

  describe "enable_event_bridge/2" do
    test "returns mocked success" do
      Sandbox.set_enable_event_bridge_responses([
        {@bucket, fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = S3.enable_event_bridge(@bucket, @sandbox_opts)
    end
  end

  describe "disable_event_bridge/2" do
    test "returns mocked success" do
      Sandbox.set_disable_event_bridge_responses([
        {@bucket, fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = S3.disable_event_bridge(@bucket, @sandbox_opts)
    end
  end

  describe "get_notification_configuration/2" do
    test "returns mocked configuration" do
      Sandbox.set_get_notification_configuration_responses([
        {@bucket, fn -> {:ok, %{event_bridge_enabled: true}} end}
      ])

      assert {:ok, %{event_bridge_enabled: true}} =
               S3.get_notification_configuration(@bucket, @sandbox_opts)
    end

    test "returns mocked configuration with EventBridge disabled" do
      Sandbox.set_get_notification_configuration_responses([
        {@bucket, fn -> {:ok, %{event_bridge_enabled: false}} end}
      ])

      assert {:ok, %{event_bridge_enabled: false}} =
               S3.get_notification_configuration(@bucket, @sandbox_opts)
    end
  end

  describe "head_bucket/2" do
    test "returns mocked headers" do
      Sandbox.set_head_bucket_responses([
        {@bucket, fn -> {:ok, %{x_amz_bucket_region: "us-east-1"}} end}
      ])

      assert {:ok, %{x_amz_bucket_region: "us-east-1"}} =
               S3.head_bucket(@bucket, @sandbox_opts)
    end

    test "returns error when bucket does not exist" do
      Sandbox.set_head_bucket_responses([
        {@bucket,
         fn -> {:error, %ErrorMessage{code: :not_found, message: "bucket not found"}} end}
      ])

      assert {:error, %ErrorMessage{code: :not_found}} = S3.head_bucket(@bucket, @sandbox_opts)
    end
  end

  describe "put_public_access_block/2" do
    test "returns mocked success" do
      Sandbox.set_put_public_access_block_responses([
        {@bucket, fn -> {:ok, %{x_amz_request_id: "req-1"}} end}
      ])

      assert {:ok, %{x_amz_request_id: "req-1"}} =
               S3.put_public_access_block(@bucket, @sandbox_opts)
    end

    test "passes opts through to the response function" do
      Sandbox.set_put_public_access_block_responses([
        {@bucket,
         fn opts ->
           assert opts[:block_public_acls] === false
           {:ok, %{}}
         end}
      ])

      assert {:ok, %{}} =
               S3.put_public_access_block(
                 @bucket,
                 Keyword.merge(@sandbox_opts, block_public_acls: false)
               )
    end
  end

  describe "put_bucket_encryption/2" do
    test "returns mocked success" do
      Sandbox.set_put_bucket_encryption_responses([
        {@bucket, fn -> {:ok, %{x_amz_request_id: "req-2"}} end}
      ])

      assert {:ok, %{x_amz_request_id: "req-2"}} =
               S3.put_bucket_encryption(@bucket, @sandbox_opts)
    end
  end

  describe "put_bucket_lifecycle_configuration/3" do
    test "returns mocked success" do
      Sandbox.set_put_bucket_lifecycle_configuration_responses([
        {@bucket, fn rules -> {:ok, %{rule_count: length(rules)}} end}
      ])

      rules = [%{id: "r1", filter: %{prefix: "logs/"}, expiration: %{days: 30}}]

      assert {:ok, %{rule_count: 1}} =
               S3.put_bucket_lifecycle_configuration(@bucket, rules, @sandbox_opts)
    end
  end

  describe "acquire_lock/3" do
    test "writes lockfile via put_new_object and returns lock metadata" do
      Sandbox.set_put_object_responses([
        {@bucket,
         fn _key, body, opts ->
           assert opts[:if_none_match] === true

           assert %{"ID" => _, "Created" => _, "Path" => path} = Jason.decode!(body)
           assert path == "#{@bucket}/lock.tflock"

           {:ok, %{etag: "etag-1"}}
         end}
      ])

      assert {:ok, %{lock_id: lock_id, key: "lock.tflock", etag: "etag-1", body: body}} =
               S3.acquire_lock(@bucket, "lock.tflock", @sandbox_opts)

      assert is_binary(lock_id) and byte_size(lock_id) === 32
      assert %{"ID" => ^lock_id} = Jason.decode!(body)
    end

    test "respects an explicit lock_id and arbitrary body" do
      Sandbox.set_put_object_responses([
        {@bucket,
         fn _key, body, _opts ->
           assert body === "raw"
           {:ok, %{etag: "x"}}
         end}
      ])

      assert {:ok, %{lock_id: "fixed", body: "raw"}} =
               S3.acquire_lock(
                 @bucket,
                 "k",
                 [lock_id: "fixed", body: "raw"] ++ @sandbox_opts
               )
    end

    test "returns conflict when S3 reports the object already exists" do
      Sandbox.set_put_object_responses([
        {@bucket,
         fn ->
           {:error, ErrorMessage.conflict("object already exists", %{bucket: @bucket, key: "k"})}
         end}
      ])

      assert {:error, %ErrorMessage{code: :conflict}} =
               S3.acquire_lock(@bucket, "k.tflock", @sandbox_opts)
    end
  end

  describe "release_lock/3" do
    test "deletes the lockfile when no lock_id is given" do
      Sandbox.set_delete_object_responses([
        {@bucket, fn _key, _opts -> {:ok, ""} end}
      ])

      assert {:ok, ""} = S3.release_lock(@bucket, "k.tflock", @sandbox_opts)
    end

    test "verifies lock_id from the body before deleting" do
      Sandbox.set_get_object_responses([
        {@bucket, fn _key -> {:ok, Jason.encode!(%{"ID" => "abc"})} end}
      ])

      Sandbox.set_delete_object_responses([
        {@bucket, fn _key, _opts -> {:ok, ""} end}
      ])

      assert {:ok, ""} =
               S3.release_lock(@bucket, "k.tflock", [lock_id: "abc"] ++ @sandbox_opts)
    end

    test "returns conflict when the body's lock id does not match" do
      Sandbox.set_get_object_responses([
        {@bucket, fn _key -> {:ok, Jason.encode!(%{"ID" => "other"})} end}
      ])

      assert {:error, %ErrorMessage{code: :conflict, message: "lock id does not match"}} =
               S3.release_lock(@bucket, "k.tflock", [lock_id: "abc"] ++ @sandbox_opts)
    end
  end

  describe "with_lock/4" do
    test "acquires, runs the function, and releases" do
      Sandbox.set_put_object_responses([
        {@bucket, fn _key, _body, _opts -> {:ok, %{etag: "e"}} end}
      ])

      Sandbox.set_get_object_responses([
        {@bucket, fn _key -> {:ok, Process.get(:lock_body)} end}
      ])

      Sandbox.set_delete_object_responses([
        {@bucket,
         fn _key, _opts ->
           send(self(), :released)
           {:ok, ""}
         end}
      ])

      result =
        S3.with_lock(
          @bucket,
          "k.tflock",
          fn lock ->
            Process.put(:lock_body, lock.body)
            {:got, lock.lock_id}
          end,
          @sandbox_opts
        )

      assert {:got, _id} = result
      assert_received :released
    end

    test "releases the lock when the function raises" do
      Sandbox.set_put_object_responses([
        {@bucket, fn _key, _body, _opts -> {:ok, %{etag: "e"}} end}
      ])

      Sandbox.set_get_object_responses([
        {@bucket, fn _key -> {:ok, Process.get(:lock_body)} end}
      ])

      Sandbox.set_delete_object_responses([
        {@bucket,
         fn _key, _opts ->
           send(self(), :released)
           {:ok, ""}
         end}
      ])

      assert_raise RuntimeError, "boom", fn ->
        S3.with_lock(
          @bucket,
          "k.tflock",
          fn lock ->
            Process.put(:lock_body, lock.body)
            raise "boom"
          end,
          @sandbox_opts
        )
      end

      assert_received :released
    end

    test "skips the function when acquisition fails" do
      Sandbox.set_put_object_responses([
        {@bucket,
         fn _key, _body, _opts ->
           {:error, ErrorMessage.conflict("object already exists", %{})}
         end}
      ])

      pid = self()

      assert {:error, %ErrorMessage{code: :conflict}} =
               S3.with_lock(@bucket, "k.tflock", fn _ -> send(pid, :ran) end, @sandbox_opts)

      refute_received :ran
    end
  end
end
