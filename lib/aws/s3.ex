defmodule AWS.S3 do
  @moduledoc """
  `AWS.S3` provides an API for working with S3 (Simple Storage Service).

  This module calls the AWS S3 REST/XML API directly via `AWS.HTTP` and
  `AWS.Signer` (through `AWS.S3.Client`). It provides consistent error
  handling, response deserialization, and sandbox support for local
  development and testing.

  S3's public API is XML-only at the AWS wire level. The service model
  (`botocore/data/s3/2006-03-01/service-2.json`) declares
  `metadata.protocols = ["rest-xml"]`, and AWS does not expose a JSON
  alternative for S3 operations. The XML handling in this module is a
  consequence of AWS's protocol choice, not a library decision: per-
  operation HTTP shapes (path, method, headers), XML response bodies
  for list/describe-style calls, and header-only response payloads for
  write-style calls. XPath extraction runs in `AWS.S3.XMLParser`;
  response-header-to-map conversion runs in `AWS.Serializer`.

  It is also the only service with first-class support for **presigned
  URLs** (via `presign/4` and `presign_part/5`), **presigned POST form
  policies** (via `presign_post/3`), and **streaming uploads** — pass an
  `Enumerable` of iodata chunks as the body to `put_object/4` or
  `upload_part/6` to avoid buffering large payloads in memory.

  ## Shared Options

  Credential and region options are flat top-level keys on every call.
  Each accepts a literal, a source tuple, or a list of sources (first
  non-nil wins). This mirrors `ExAws.Config`.

    - `:access_key_id` - AWS access key ID. Sources: literal binary,
      `{:system, "ENV"}`, `:instance_role`, `:ecs_task_role`,
      `{:awscli, profile}` / `{:awscli, profile, ttl_seconds}`, a module,
      or a list of any of these.

    - `:secret_access_key` - AWS secret access key. Same source vocabulary.

    - `:security_token` - STS session token. Same source vocabulary.

    - `:region` - AWS region. Same source vocabulary. Defaults to
      `AWS.Config.region()`.

  If a source returns a map (e.g. `:instance_role` or `{:awscli, _}`),
  its fields are merged into the resolved config, so listing
  `:instance_role` under `:access_key_id` also populates
  `:secret_access_key` and `:security_token`.

  `{:awscli, _}` is **not** in the default chain — callers opt in
  explicitly. Reading `~/.aws/*` silently on server runtimes is surprising.

  The following options are also available for most functions:

    - `:s3` - A keyword list of S3-specific endpoint overrides. Supports
      `:scheme`, `:host`, `:port`, `:path_style`. Credentials are not
      read from this sub-list; use the top-level keys above.

    - `:sandbox` - A keyword list to override sandbox configuration. Each
      key falls back to the corresponding entry in `AWS.Config.sandbox/0`.
        - `:enabled` - Whether sandbox mode is enabled.
        - `:mode` - Controls whether the sandbox uses an emulated service or an OTP process.
          - When the mode is `:local`, the sandbox makes HTTP calls to a sandboxed service such as localstack.
          - When the mode is `:inline`, the sandbox uses an OTP process to handle requests.
        - `:scheme` - The sandbox scheme.
        - `:host` - The sandbox host.
        - `:port` - The sandbox port.

  ## Sandbox

  This API provides a sandbox that you can use during development and testing
  to mock S3 operations without making real HTTP calls.

  Set `sandbox: [enabled: true, mode: :inline]` to activate inline sandbox mode.

  ### Setup

  Add the following to your `test_helper.exs`:

      AWS.S3.Sandbox.start_link()

  ### Usage

  Register mock responses in your test `setup` block, then pass
  `sandbox: [enabled: true, mode: :inline]` to any S3 function:

      setup do
        AWS.S3.Sandbox.set_get_object_responses([
          {"my-bucket", fn key -> {:ok, "content for \#{key}"} end}
        ])
      end

      test "gets an object" do
        assert {:ok, "content for my-key"} =
                 AWS.S3.get_object("my-bucket", "my-key",
                   sandbox: [enabled: true, mode: :inline]
                 )
      end

  ### Bucket Matching

  Each registration tuple has two elements:

    - A **bucket name** (exact string match) or a **regex** (`~r/pattern/`)
    - A **function** that returns the mocked response

  For `list_buckets`, pass a list of bare functions (no bucket tuple needed).

  ### Variable Arity

  Response functions support variable arity. For example,
  `set_get_object_responses/1` accepts functions with 0, 1, or 2 parameters:

      fn -> {:ok, "static"} end
      fn key -> {:ok, "content for \#{key}"} end
      fn key, opts -> {:ok, "content"} end
  """

  alias AWS.{
    Client,
    Config,
    Error,
    S3.Multipart,
    S3.Operation,
    S3.XMLBuilder,
    S3.XMLParser,
    Serializer,
    Signer
  }

  @override_keys [:headers, :body, :http, :url, :stream_upload, :stream_response, :payload_hash]

  @service "s3"
  @sixty_four_mib 64 * 1_024 * 1_024
  @one_gib 1 * 1_024 * 1_024 * 1_024
  @sixty_seconds 60

  @doc """
  Returns a list of all buckets owned by the authenticated sender of the request.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:ListAllMyBuckets

  ## Arguments

    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.list_buckets()
      {:ok, [%{name: "my-bucket", creation_date: "2024-01-01T00:00:00.000Z"}]}
  """
  @spec list_buckets(opts :: keyword()) :: {:ok, list()} | {:error, term()}
  def list_buckets(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_buckets_response(opts)
    else
      do_list_buckets(opts)
    end
  end

  @doc """
  Creates a bucket in the specified region.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:CreateBucket

  ## Arguments

    * `bucket` - The name of the bucket to create.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.create_bucket("my-bucket")
      {:ok, %{location: "...", x_amz_request_id: "...", date: "..."}}
  """
  @spec create_bucket(bucket :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_bucket(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_bucket_response(bucket, opts)
    else
      do_create_bucket(bucket, opts)
    end
  end

  @doc """
  Deletes an empty bucket.

  Returns `{:error, :not_found}` if the bucket does not exist and
  `{:error, :conflict}` if the bucket is not empty.

  ## Arguments

    * `bucket` - The name of the bucket to delete.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.delete_bucket("my-bucket")
      {:ok, %{x_amz_request_id: "...", date: "..."}}
  """
  @spec delete_bucket(bucket :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def delete_bucket(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_bucket_response(bucket, opts)
    else
      do_delete_bucket(bucket, opts)
    end
  end

  @doc """
  Determines whether a bucket exists and the caller has permission to access it.

  Returns `{:ok, headers}` when the bucket exists and is accessible (the response
  body is empty; useful headers such as `x-amz-bucket-region` are returned).
  Returns `{:error, :not_found}` when the bucket does not exist or the caller
  lacks permission.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:ListBucket

  ## Arguments

    * `bucket` - The name of the bucket to check.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.head_bucket("my-bucket")
      {:ok, %{x_amz_bucket_region: "us-east-1", x_amz_request_id: "...", date: "..."}}
  """
  @spec head_bucket(bucket :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def head_bucket(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_head_bucket_response(bucket, opts)
    else
      do_head_bucket(bucket, opts)
    end
  end

  @doc """
  Uploads an object to a bucket.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:PutObject

  ## Arguments

    * `bucket` - The name of the bucket to upload to.
    * `key` - The key under which to store the object.
    * `body` - The content to upload (iodata, or an `Enumerable` of iodata chunks for streaming).
    * `opts` - A keyword list of options.

  ## Options

    * `:content_type` - Explicit `content-type` header for the object.
    * `:acl` - Canned ACL (maps to `x-amz-acl`).
    * `:headers` - Additional raw request headers.

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.put_object("my-bucket", "my-key", "hello world")
      {:ok, %{etag: "...", x_amz_request_id: "..."}}
  """
  @spec put_object(
          bucket :: binary(),
          key :: binary(),
          body :: iodata() | Enumerable.t(),
          opts :: keyword()
        ) ::
          {:ok, map()} | {:error, term()}
  def put_object(bucket, key, body, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_object_response(bucket, key, body, opts)
    else
      do_put_object(bucket, key, body, opts)
    end
  end

  @doc """
  Returns the metadata of an object stored in S3 without returning the object itself.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:GetObject

  ## Arguments

    * `bucket` - The name of the bucket containing the object.
    * `key` - The key of the object to retrieve metadata for.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.head_object("my-bucket", "my-key")
      {:ok, %{content_length: "1234", content_type: "application/json", ...}}
  """
  @spec head_object(bucket :: binary(), key :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def head_object(bucket, key, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_head_object_response(bucket, key, opts)
    else
      do_head_object(bucket, key, opts)
    end
  end

  @doc """
  Deletes an object from a bucket.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:DeleteObject

  ## Arguments

    * `bucket` - The name of the bucket containing the object.
    * `key` - The key of the object to delete.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.delete_object("my-bucket", "my-key")
      {:ok, ""}
  """
  @spec delete_object(bucket :: binary(), key :: binary(), opts :: keyword()) ::
          {:ok, term()} | {:error, term()}
  def delete_object(bucket, key, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_object_response(bucket, key, opts)
    else
      do_delete_object(bucket, key, opts)
    end
  end

  @doc """
  Returns the content of an object stored in S3.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:GetObject

  ## Arguments

    * `bucket` - The name of the bucket containing the object.
    * `key` - The key of the object to retrieve.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.get_object("my-bucket", "my-key")
      {:ok, <<binary_content>>}
  """
  @spec get_object(bucket :: binary(), key :: binary(), opts :: keyword()) ::
          {:ok, binary()} | {:error, term()}
  def get_object(bucket, key, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_object_response(bucket, key, opts)
    else
      do_get_object(bucket, key, opts)
    end
  end

  @doc """
  Returns a list of objects in a bucket.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:ListBucket

  ## Arguments

    * `bucket` - The name of the bucket to list objects from.
    * `opts` - A keyword list of options.

  ## Options

    * `:prefix` - Limit the response to keys that begin with the specified prefix.
    * `:delimiter` - Groups keys that contain the delimiter into a single result.
    * `:max_keys` - Maximum number of keys returned (up to 1000).
    * `:start_after` - Start listing after this key.
    * `:continuation_token` - Pagination token from a previous response.
    * `:fetch_owner` - Whether to include bucket owner info.
    * `:encoding_type` - Encoding method for response keys.

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.list_objects("my-bucket")
      {:ok, [%{key: "my-key", size: "1234", ...}]}
  """
  @spec list_objects(bucket :: binary(), opts :: keyword()) ::
          {:ok, list()} | {:error, term()}
  def list_objects(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_objects_response(bucket, opts)
    else
      do_list_objects(bucket, opts)
    end
  end

  @doc """
  Copies an object from one bucket to another.

  ## Permissions

  To execute this request, you must have the following permissions:

    - s3:GetObject (on the source bucket)
    - s3:PutObject (on the destination bucket)

  ## Arguments

    * `dest_bucket` - The name of the destination bucket.
    * `dest_key` - The key for the copied object in the destination bucket.
    * `src_bucket` - The name of the source bucket.
    * `src_key` - The key of the object to copy from the source bucket.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.copy_object("dest-bucket", "dest-key", "src-bucket", "src-key")
      {:ok, %{etag: "...", last_modified: "..."}}
  """
  @spec copy_object(
          dest_bucket :: binary(),
          dest_key :: binary(),
          src_bucket :: binary(),
          src_key :: binary(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def copy_object(dest_bucket, dest_key, src_bucket, src_key, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_copy_object_response(dest_bucket, dest_key, src_bucket, src_key, opts)
    else
      do_copy_object(dest_bucket, dest_key, src_bucket, src_key, opts)
    end
  end

  @doc """
  Returns a presigned URL for an object.

  The presigned URL allows temporary access to the object without requiring
  AWS credentials from the requester.

  ## Permissions

  The credentials used to generate the presigned URL must have the permission
  required for the corresponding HTTP method:

    - `:get` — s3:GetObject
    - `:put` — s3:PutObject
    - `:delete` — s3:DeleteObject
    - `:head` — s3:GetObject

  ## Arguments

    * `bucket` - The name of the bucket containing the object.
    * `http_method` - The HTTP method to presign (e.g., `:get`, `:put`, `:post`, `:delete`, `:head`).
    * `key` - The key of the object.
    * `opts` - A keyword list of options.

  ## Options

    - `:expires_in` - The number of seconds until the presigned URL expires. Defaults to 60.
    - `:query_params` - Additional query parameters to include in the signed URL.

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.presign("my-bucket", :get, "my-key")
      %{key: "my-key", url: "https://...", expires_in: 60, expires_at: ~U[...]}
  """
  @spec presign(bucket :: binary(), http_method :: atom(), key :: binary(), opts :: keyword()) ::
          map()
  def presign(bucket, http_method, key, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_presign_response(bucket, http_method, key, opts)
    else
      do_presign(bucket, http_method, key, opts)
    end
  end

  @doc """
  Returns a presigned POST configuration for uploading an object directly to S3.

  The presigned POST includes a URL and form fields that can be used in an
  HTML form or multipart upload to upload an object without server-side proxying.

  ## Permissions

  The credentials used to generate the presigned POST must have the following permission:

    - s3:PutObject

  ## Arguments

    * `bucket` - The name of the bucket to upload to.
    * `key` - The key under which the object will be stored.
    * `opts` - A keyword list of options.

  ## Options

    * `:expires_in` - The number of seconds until the presigned POST expires. Defaults to 60.
    * `:min_size` - Minimum allowed upload size in bytes. Defaults to 0.
    * `:max_size` - Maximum allowed upload size in bytes. Defaults to 1 GiB.
    * `:content_type` - Optional content type prefix for the upload condition.

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.presign_post("my-bucket", "my-key")
      {:ok, %{fields: %{...}, url: "https://...", expires_in: 60, expires_at: ~U[...]}}
  """
  @spec presign_post(bucket :: binary(), key :: binary(), opts :: keyword()) ::
          {:ok, map()}
  def presign_post(bucket, key, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_presign_post_response(bucket, key, opts)
    else
      do_presign_post(bucket, key, opts)
    end
  end

  @doc """
  Returns a presigned URL for uploading a part of a multipart upload.

  This is a convenience wrapper around `presign/4` that adds the required
  `uploadId` and `partNumber` query parameters for multipart upload parts.

  ## Permissions

  The credentials used to generate the presigned URL must have the following permission:

    - s3:PutObject

  ## Arguments

    * `bucket` - The name of the bucket.
    * `object` - The key of the object being uploaded.
    * `upload_id` - The upload ID of the multipart upload.
    * `part_number` - The part number of the part to upload.
    * `opts` - A keyword list of options.

  ## Options

  See `presign/4` for available options.

  ## Examples

      iex> AWS.S3.presign_part("my-bucket", "my-key", "upload-id", 1)
      %{key: "my-key", url: "https://...", expires_in: 60, expires_at: ~U[...]}
  """
  @spec presign_part(
          bucket :: binary(),
          object :: binary(),
          upload_id :: binary(),
          part_number :: integer(),
          opts :: keyword()
        ) :: map()
  def presign_part(bucket, object, upload_id, part_number, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_presign_part_response(bucket, object, upload_id, part_number, opts)
    else
      do_presign_part(bucket, object, upload_id, part_number, opts)
    end
  end

  @doc """
  Initiates a multipart upload and returns the upload ID.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:PutObject

  ## Arguments

    * `bucket` - The name of the bucket.
    * `key` - The key of the object to upload.
    * `opts` - A keyword list of options.

  ## Options

    - `:expires` - An expiry value for the multipart upload. Accepts a `DateTime`, an HTTP date
      string, or `nil` (defaults to 1 minute from now).

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.create_multipart_upload("my-bucket", "my-key")
      {:ok, %{upload_id: "...", bucket: "my-bucket", key: "my-key"}}
  """
  @spec create_multipart_upload(bucket :: binary(), key :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_multipart_upload(bucket, key, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_multipart_upload_response(bucket, key, opts)
    else
      do_create_multipart_upload(bucket, key, opts)
    end
  end

  @doc """
  Aborts a multipart upload.

  After aborting, any previously uploaded parts are deleted and no further
  parts can be uploaded using the same upload ID.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:AbortMultipartUpload

  ## Arguments

    * `bucket` - The name of the bucket.
    * `key` - The key of the object.
    * `upload_id` - The upload ID of the multipart upload to abort.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.abort_multipart_upload("my-bucket", "my-key", "upload-id")
      {:ok, %{}}
  """
  @spec abort_multipart_upload(
          bucket :: binary(),
          key :: binary(),
          upload_id :: binary(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def abort_multipart_upload(bucket, key, upload_id, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_abort_multipart_upload_response(bucket, key, upload_id, opts)
    else
      do_abort_multipart_upload(bucket, key, upload_id, opts)
    end
  end

  @doc """
  Uploads a part of a multipart upload.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:PutObject

  ## Arguments

    * `bucket` - The name of the bucket.
    * `key` - The key of the object.
    * `upload_id` - The upload ID of the multipart upload.
    * `part_number` - The part number (1 to 10,000).
    * `body` - The content of the part (iodata, or an `Enumerable` for streaming).
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.upload_part("my-bucket", "my-key", "upload-id", 1, "part-data")
      {:ok, %{etag: "...", ...}}
  """
  @spec upload_part(
          bucket :: binary(),
          key :: binary(),
          upload_id :: binary(),
          part_number :: integer(),
          body :: iodata() | Enumerable.t(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def upload_part(bucket, key, upload_id, part_number, body, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_upload_part_response(bucket, key, upload_id, part_number, body, opts)
    else
      do_upload_part(bucket, key, upload_id, part_number, body, opts)
    end
  end

  @doc """
  Returns a list of parts that have been uploaded for a multipart upload.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:ListMultipartUploadParts

  ## Arguments

    * `bucket` - The name of the bucket.
    * `key` - The key of the object.
    * `upload_id` - The upload ID of the multipart upload.
    * `part_number_marker` - Specifies the part after which listing should begin.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.list_parts("my-bucket", "my-key", "upload-id")
      {:ok, %{parts: [%{part_number: "1", size: "5242880", etag: "..."}], ...}}
  """
  @spec list_parts(
          bucket :: binary(),
          key :: binary(),
          upload_id :: binary(),
          part_number_marker :: binary() | nil,
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def list_parts(bucket, key, upload_id, part_number_marker \\ nil, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_parts_response(bucket, key, upload_id, part_number_marker, opts)
    else
      do_list_parts(bucket, key, upload_id, part_number_marker, opts)
    end
  end

  @doc """
  Copies a part from a source object to a destination object as part of a multipart upload.

  ## Permissions

  To execute this request, you must have the following permissions:

    - s3:GetObject (on the source bucket)
    - s3:PutObject (on the destination bucket)

  ## Arguments

    * `dest_bucket` - The name of the destination bucket.
    * `dest_key` - The key for the copied object in the destination bucket.
    * `src_bucket` - The name of the source bucket.
    * `src_key` - The key of the source object.
    * `upload_id` - The upload ID of the multipart upload.
    * `part_number` - The part number for this copy.
    * `src_range` - The byte range to copy from the source (e.g., `0..1048575`).
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.copy_part("dest-bucket", "dest-key", "src-bucket", "src-key", "upload-id", 1, 0..1048575)
      {:ok, %{etag: "...", last_modified: "..."}}
  """
  @spec copy_part(
          dest_bucket :: binary(),
          dest_key :: binary(),
          src_bucket :: binary(),
          src_key :: binary(),
          upload_id :: binary(),
          part_number :: integer(),
          src_range :: Range.t(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def copy_part(
        dest_bucket,
        dest_key,
        src_bucket,
        src_key,
        upload_id,
        part_number,
        src_range,
        opts
      ) do
    if inline_sandbox?(opts) do
      sandbox_copy_part_response(
        dest_bucket,
        dest_key,
        src_bucket,
        src_key,
        upload_id,
        part_number,
        src_range,
        opts
      )
    else
      do_copy_part(
        dest_bucket,
        dest_key,
        src_bucket,
        src_key,
        upload_id,
        part_number,
        src_range,
        opts
      )
    end
  end

  @doc """
  Copies parts of an object from one location to another using concurrent
  multipart copy operations.

  Partitions the source object into byte-range chunks and copies each
  chunk concurrently using `Task.async_stream/3`.

  ## Permissions

  To execute this request, you must have the following permissions:

    - s3:GetObject (on the source bucket)
    - s3:PutObject (on the destination bucket)

  ## Arguments

    * `dest_bucket` - The name of the destination bucket.
    * `dest_key` - The key for the copied object in the destination bucket.
    * `src_bucket` - The name of the source bucket.
    * `src_key` - The key of the source object.
    * `upload_id` - The upload ID of the multipart upload.
    * `content_length` - The total size of the source object in bytes.
    * `opts` - A keyword list of options.

  ## Options

    * `:content_byte_stream` - A keyword list of byte stream options:
      * `:byte_range_index` - The byte offset to start from. Defaults to 0.
      * `:chunk_size` - The size of each chunk in bytes. Defaults to 64 MiB.
      * `:max_concurrency` - Maximum number of concurrent copy tasks. Defaults to `System.schedulers_online()`.
      * `:timeout` - Timeout per task in milliseconds.
      * `:on_timeout` - What to do on timeout.

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.copy_parts("dest-bucket", "dest-key", "src-bucket", "src-key", "upload-id", 67_108_864)
      {:ok, [{1, "etag1"}, {2, "etag2"}]}
  """
  @spec copy_parts(
          dest_bucket :: binary(),
          dest_key :: binary(),
          src_bucket :: binary(),
          src_key :: binary(),
          upload_id :: binary(),
          content_length :: integer(),
          opts :: keyword()
        ) :: {:ok, list()} | {:error, list()}
  def copy_parts(
        dest_bucket,
        dest_key,
        src_bucket,
        src_key,
        upload_id,
        content_length,
        opts \\ []
      ) do
    if inline_sandbox?(opts) do
      sandbox_copy_parts_response(
        dest_bucket,
        dest_key,
        src_bucket,
        src_key,
        upload_id,
        content_length,
        opts
      )
    else
      do_copy_parts(
        dest_bucket,
        dest_key,
        src_bucket,
        src_key,
        upload_id,
        content_length,
        opts
      )
    end
  end

  @doc """
  Copies an object from one location to another using multipart upload.

  Orchestrates a full multipart copy workflow: retrieves the source object's
  metadata, initiates a multipart upload, copies all parts concurrently,
  and completes the multipart upload.

  ## Permissions

  To execute this request, you must have the following permissions:

    - s3:GetObject (on the source bucket)
    - s3:PutObject (on the destination bucket)
    - s3:ListMultipartUploadParts (on the destination bucket, required for size validation)

  ## Arguments

    * `dest_bucket` - The name of the destination bucket.
    * `dest_key` - The key for the copied object in the destination bucket.
    * `src_bucket` - The name of the source bucket.
    * `src_key` - The key of the source object.
    * `opts` - A keyword list of options.

  ## Options

  See `copy_parts/7` for byte stream options.
  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.copy_object_multipart("dest-bucket", "dest-key", "src-bucket", "src-key")
      {:ok, %{location: "...", bucket: "dest-bucket", key: "dest-key", etag: "..."}}
  """
  @spec copy_object_multipart(
          dest_bucket :: binary(),
          dest_key :: binary(),
          src_bucket :: binary(),
          src_key :: binary(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def copy_object_multipart(dest_bucket, dest_key, src_bucket, src_key, opts \\ []) do
    do_copy_object_multipart(dest_bucket, dest_key, src_bucket, src_key, opts)
  end

  @doc """
  Completes a multipart upload by assembling previously uploaded parts.

  Optionally validates the total upload size against a maximum and checks the
  content type of the completed object.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:PutObject

  The following permissions may also be required depending on options:

    - s3:ListMultipartUploadParts (required when `:max_size` validation is enabled, which is the default)
    - s3:GetObject (required when `:content_type` validation is enabled)
    - s3:DeleteObject (required when `:on_content_type_mismatch` is `:delete`, which is the default)

  ## Arguments

    * `bucket` - The name of the bucket.
    * `key` - The key of the object.
    * `upload_id` - The upload ID of the multipart upload.
    * `parts` - A list of `{part_number, etag}` tuples.
    * `opts` - A keyword list of options.

  ## Options

    * `:max_size` - Maximum allowed total size in bytes. Defaults to 1 GiB. Set to `:infinity`,
      `false`, or `nil` to disable size validation.

    * `:content_type` - Expected content type of the completed object. Set to `:any` to skip
      content type validation.

    * `:on_content_type_mismatch` - Action to take when content type doesn't match.
      `:delete` (default) deletes the object, `:error` returns an error without deleting.

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.complete_multipart_upload("my-bucket", "my-key", "upload-id", [{1, "etag1"}, {2, "etag2"}])
      {:ok, %{location: "...", bucket: "my-bucket", key: "my-key", etag: "..."}}
  """
  @spec complete_multipart_upload(
          bucket :: binary(),
          key :: binary(),
          upload_id :: binary(),
          parts :: list(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def complete_multipart_upload(bucket, key, upload_id, parts, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_complete_multipart_upload_response(bucket, key, upload_id, parts, opts)
    else
      do_complete_multipart_upload(bucket, key, upload_id, parts, opts)
    end
  end

  # S3 EventBridge notification configuration

  @doc """
  Enables EventBridge notifications on an S3 bucket.

  Once enabled, all S3 event types are sent to EventBridge. Filtering is done at
  the EventBridge rule level via event patterns. Existing notification configurations
  (SNS, SQS, Lambda) are preserved.

  Idempotent — returns `{:ok, %{}}` if EventBridge is already enabled.
  """
  @spec enable_event_bridge(bucket :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def enable_event_bridge(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_enable_event_bridge_response(bucket, opts)
    else
      do_enable_event_bridge(bucket, opts)
    end
  end

  @doc """
  Disables EventBridge notifications on an S3 bucket.

  Other notification configurations (SNS, SQS, Lambda) are preserved.

  Idempotent — returns `{:ok, %{}}` if EventBridge is not currently enabled.
  """
  @spec disable_event_bridge(bucket :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def disable_event_bridge(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_disable_event_bridge_response(bucket, opts)
    else
      do_disable_event_bridge(bucket, opts)
    end
  end

  @doc """
  Returns the notification configuration for an S3 bucket.

  The result includes `:event_bridge_enabled` (boolean) and `:raw_xml` (the original XML).
  """
  @spec get_notification_configuration(bucket :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_notification_configuration(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_notification_configuration_response(bucket, opts)
    else
      do_get_notification_configuration(bucket, opts)
    end
  end

  # S3 bucket configuration

  @doc """
  Sets the public access block configuration for a bucket.

  All four flags default to `true` (the most restrictive setting). Pass
  `false` for any flag you want to relax.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:PutBucketPublicAccessBlock

  ## Arguments

    * `bucket` - The name of the bucket.
    * `opts` - A keyword list of options.

  ## Options

    * `:block_public_acls` - Reject public ACLs on this bucket and its objects. Defaults to `true`.
    * `:ignore_public_acls` - Ignore public ACLs on this bucket and its objects. Defaults to `true`.
    * `:block_public_policy` - Reject bucket policies that grant public access. Defaults to `true`.
    * `:restrict_public_buckets` - Restrict cross-account access to buckets with public policies. Defaults to `true`.

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.put_public_access_block("my-bucket")
      {:ok, %{x_amz_request_id: "...", date: "..."}}

      iex> AWS.S3.put_public_access_block("my-bucket", block_public_acls: false)
      {:ok, %{x_amz_request_id: "...", date: "..."}}
  """
  @spec put_public_access_block(bucket :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def put_public_access_block(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_public_access_block_response(bucket, opts)
    else
      do_put_public_access_block(bucket, opts)
    end
  end

  @doc """
  Sets the default server-side encryption configuration for a bucket.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:PutEncryptionConfiguration

  ## Arguments

    * `bucket` - The name of the bucket.
    * `opts` - A keyword list of options.

  ## Options

    * `:sse_algorithm` - The server-side encryption algorithm. One of `"AES256"` (default),
      `"aws:kms"`, or `"aws:kms:dsse"`.
    * `:kms_master_key_id` - The KMS key ID or ARN to use for encryption. Required when
      `:sse_algorithm` is a KMS variant.
    * `:bucket_key_enabled` - Whether to enable S3 Bucket Keys to reduce KMS request costs.

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.put_bucket_encryption("my-bucket")
      {:ok, %{x_amz_request_id: "...", date: "..."}}

      iex> AWS.S3.put_bucket_encryption("my-bucket",
      ...>   sse_algorithm: "aws:kms",
      ...>   kms_master_key_id: "arn:aws:kms:us-east-1:111122223333:key/abcd",
      ...>   bucket_key_enabled: true
      ...> )
      {:ok, %{x_amz_request_id: "...", date: "..."}}
  """
  @spec put_bucket_encryption(bucket :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def put_bucket_encryption(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_bucket_encryption_response(bucket, opts)
    else
      do_put_bucket_encryption(bucket, opts)
    end
  end

  @doc """
  Sets the lifecycle configuration for a bucket.

  Replaces any existing lifecycle configuration. Pass an empty list to clear all rules
  (note that AWS requires at least one rule, so to remove the configuration entirely
  use the DELETE Bucket lifecycle API instead).

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:PutLifecycleConfiguration

  ## Arguments

    * `bucket` - The name of the bucket.
    * `rules` - A list of rule maps. Each rule supports the following keys:

      * `:id` - Required. A unique identifier for the rule (max 255 characters).
      * `:status` - `"Enabled"` (default) or `"Disabled"`.
      * `:filter` - A map describing which objects the rule applies to. Common shapes:
        * `%{prefix: "logs/"}` - prefix-only filter
        * `%{}` - empty filter (applies to all objects)
        * `%{object_size_greater_than: 1024}` / `%{object_size_less_than: 1_000_000}`
        * `%{tag: %{key: "k", value: "v"}}` - single tag
        Defaults to an empty filter.
      * `:expiration` - A map. Examples: `%{days: 30}`, `%{date: "2026-01-01T00:00:00Z"}`,
        `%{expired_object_delete_marker: true}`.
      * `:transitions` - A list of `%{days: N, storage_class: "GLACIER"}` (or `:date`).
      * `:noncurrent_version_expiration` - `%{noncurrent_days: N}`.
      * `:noncurrent_version_transitions` - A list of `%{noncurrent_days: N, storage_class: "..."}`.
      * `:abort_incomplete_multipart_upload` - `%{days_after_initiation: N}`.

    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.

  ## Examples

      iex> AWS.S3.put_bucket_lifecycle_configuration("my-bucket", [
      ...>   %{id: "expire-logs", filter: %{prefix: "logs/"}, expiration: %{days: 30}}
      ...> ])
      {:ok, %{x_amz_request_id: "...", date: "..."}}
  """
  @spec put_bucket_lifecycle_configuration(
          bucket :: binary(),
          rules :: list(map()),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def put_bucket_lifecycle_configuration(bucket, rules, opts \\ []) when is_list(rules) do
    if inline_sandbox?(opts) do
      sandbox_put_bucket_lifecycle_configuration_response(bucket, rules, opts)
    else
      do_put_bucket_lifecycle_configuration(bucket, rules, opts)
    end
  end

  @doc false
  def build_operation(method, bucket, key, opts) do
    with {:ok, config} <- resolve_config(opts) do
      user_headers = Keyword.get(opts, :headers, [])
      query = Keyword.get(opts, :query, %{})
      body = Keyword.get(opts, :body, "")
      stream_response? = Keyword.get(opts, :stream_response, false)

      url = build_url(config, bucket, key, query)
      {payload_hash, stream_upload?} = classify_body(body)

      op = %Operation{
        method: method,
        url: url,
        headers: user_headers,
        body: body,
        service: @service,
        region: config.region,
        access_key_id: config.access_key_id,
        secret_access_key: config.secret_access_key,
        security_token: config.security_token,
        payload_hash: payload_hash,
        stream_upload: stream_upload?,
        stream_response: stream_response?,
        http: Keyword.get(opts, :http, [])
      }

      {:ok, apply_overrides(op, opts[:s3] || [])}
    end
  end

  @doc """
  Returns the URL a caller would hit for `{bucket, key, query}` given
  `opts`. Used by presigning so the SigV4 signature lines up with the
  URL built by `s3_request/4`.
  """
  @spec build_url(keyword | map, binary | nil, binary | nil, map | keyword) :: String.t()
  def build_url(opts, bucket, key, query) when is_list(opts) do
    case resolve_config(opts) do
      {:ok, config} -> build_url(config, bucket, key, query)
      {:error, reason} -> raise ArgumentError, "cannot build S3 URL: #{inspect(reason)}"
    end
  end

  def build_url(config, bucket, key, query) when is_map(config) do
    {host, path_prefix} = address(config, bucket)
    base_path = build_base_path(path_prefix, key)
    port_part = port_suffix(config.scheme, config.port)
    query_part = build_query_part(query)

    "#{config.scheme}://#{host}#{port_part}#{base_path}#{query_part}"
  end

  @doc """
  Resolves the full config map (region, scheme, host, port, creds,
  path_style) for a given opts keyword. Exposed so presigners can reuse it.
  """
  @spec resolve_config(keyword) :: {:ok, map} | {:error, term}
  def resolve_config(opts) do
    {sandbox_opts, _} = Keyword.pop(opts, :sandbox, [])

    with {:ok, config} <-
           Client.resolve_config(:s3, opts, &"s3.#{&1}.amazonaws.com", [:path_style]) do
      path_style = resolve_path_style(config.path_style, sandbox_opts)
      {:ok, Map.put(config, :path_style, path_style)}
    end
  end

  defp do_list_buckets(opts) do
    :get
    |> s3_request(nil, nil, opts)
    |> deserialize_response(opts, fn %{body: body} ->
      body
      |> XMLParser.parse_list_buckets()
      |> Map.fetch!(:buckets)
    end)
  end

  defp do_create_bucket(bucket, opts) do
    region = opts[:region] || Config.region() || "us-east-1"
    body = create_bucket_body(region)

    case s3_request(:put, bucket, nil, Keyword.put(opts, :body, body)) do
      {:error, {:http_error, 409, _resp}} ->
        {:error,
         Error.conflict(
           "bucket already exists",
           %{bucket: bucket, region: region},
           opts
         )}

      result ->
        deserialize_response(result, opts, fn %{headers: headers} ->
          headers
          |> Serializer.deserialize()
          |> Map.new()
        end)
    end
  end

  defp create_bucket_body("us-east-1"), do: ""

  defp create_bucket_body(region) do
    "<CreateBucketConfiguration><LocationConstraint>#{region}</LocationConstraint></CreateBucketConfiguration>"
  end

  defp do_delete_bucket(bucket, opts) do
    :delete
    |> s3_request(bucket, nil, opts)
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize()
      |> Map.new()
    end)
  end

  defp do_head_bucket(bucket, opts) do
    :head
    |> s3_request(bucket, nil, opts)
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize()
      |> Map.new()
    end)
  end

  defp do_put_object(bucket, key, body, opts) do
    headers = object_headers(opts)

    :put
    |> s3_request(bucket, key, put_opts(opts, body: body, headers: headers))
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize()
      |> Map.new()
    end)
  end

  defp do_head_object(bucket, key, opts) do
    :head
    |> s3_request(bucket, key, opts)
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize()
      |> Map.new()
    end)
  end

  defp do_delete_object(bucket, key, opts) do
    :delete
    |> s3_request(bucket, key, opts)
    |> deserialize_response(opts, fn %{body: body} -> body end)
  end

  defp do_get_object(bucket, key, opts) do
    :get
    |> s3_request(bucket, key, opts)
    |> deserialize_response(opts, fn %{body: body} -> body end)
  end

  defp do_list_objects(bucket, opts) do
    query = list_objects_query(opts)

    :get
    |> s3_request(bucket, nil, Keyword.put(opts, :query, query))
    |> deserialize_response(opts, fn %{body: body} ->
      body
      |> XMLParser.parse_list_objects()
      |> Map.fetch!(:contents)
    end)
  end

  defp list_objects_query(opts) do
    %{"list-type" => "2"}
    |> maybe_put_query("prefix", opts[:prefix])
    |> maybe_put_query("delimiter", opts[:delimiter])
    |> maybe_put_query("max-keys", opts[:max_keys])
    |> maybe_put_query("start-after", opts[:start_after])
    |> maybe_put_query("continuation-token", opts[:continuation_token])
    |> maybe_put_query("fetch-owner", opts[:fetch_owner])
    |> maybe_put_query("encoding-type", opts[:encoding_type])
  end

  defp do_copy_object(dest_bucket, dest_key, src_bucket, src_key, opts) do
    headers = [{"x-amz-copy-source", copy_source(src_bucket, src_key)}]

    :put
    |> s3_request(dest_bucket, dest_key, put_opts(opts, body: "", headers: headers))
    |> deserialize_response(opts, fn %{body: body} ->
      XMLParser.parse_copy_object_result(body)
    end)
  end

  defp do_presign(bucket, http_method, key, opts) do
    expires_in = opts[:expires_in] || @sixty_seconds
    {:ok, config} = resolve_config(opts)
    query_params = Map.new(opts[:query_params] || %{})
    url = build_url(config, bucket, key, query_params)

    signed_url = Signer.sign_query(http_method, url, [], expires_in, signer_creds(config))

    %{
      key: key,
      url: signed_url,
      expires_in: expires_in,
      expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
    }
  end

  defp do_presign_post(bucket, key, opts) do
    expires_in = opts[:expires_in] || @sixty_seconds
    min_size = Keyword.get(opts, :min_size, 0)
    max_size = Keyword.get(opts, :max_size, @one_gib)

    {:ok, config} = resolve_config(opts)
    url = build_url(config, bucket, nil, %{})

    conditions =
      maybe_add_content_type_condition(
        [
          %{"bucket" => bucket},
          %{"key" => key},
          ["content-length-range", min_size, max_size]
        ],
        opts[:content_type]
      )

    result = Signer.presign_post_policy(url, conditions, expires_in, signer_creds(config))

    fields =
      result.fields
      |> Map.put("key", key)
      |> Serializer.deserialize()

    {:ok,
     %{
       fields: fields,
       url: result.url,
       expires_in: expires_in,
       expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
     }}
  end

  defp maybe_add_content_type_condition(conditions, nil), do: conditions

  defp maybe_add_content_type_condition(conditions, content_type) do
    conditions ++ [["starts-with", "$Content-Type", content_type]]
  end

  defp do_presign_part(bucket, object, upload_id, part_number, opts) do
    query_params = %{"uploadId" => upload_id, "partNumber" => to_string(part_number)}
    opts = Keyword.update(opts, :query_params, query_params, &Map.merge(&1, query_params))
    presign(bucket, :put, object, opts)
  end

  defp do_create_multipart_upload(bucket, key, opts) do
    expires = resolve_expires(opts[:expires])
    headers = object_headers(opts) ++ maybe_expires_header(expires)

    :post
    |> s3_request(
      bucket,
      key,
      put_opts(opts, query: %{"uploads" => ""}, body: "", headers: headers)
    )
    |> deserialize_response(opts, fn %{body: body} ->
      XMLParser.parse_initiate_multipart(body)
    end)
  end

  defp resolve_expires(nil) do
    DateTime.utc_now()
    |> DateTime.add(1, :minute)
    |> to_http_date()
  end

  defp resolve_expires(%DateTime{} = datetime), do: to_http_date(datetime)
  defp resolve_expires(expires) when is_binary(expires), do: expires

  defp maybe_expires_header(nil), do: []
  defp maybe_expires_header(expires), do: [{"expires", expires}]

  defp do_abort_multipart_upload(bucket, key, upload_id, opts) do
    :delete
    |> s3_request(bucket, key, Keyword.put(opts, :query, %{"uploadId" => upload_id}))
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize()
      |> Map.new()
    end)
  end

  defp do_upload_part(bucket, key, upload_id, part_number, body, opts) do
    query = %{"uploadId" => upload_id, "partNumber" => to_string(part_number)}

    :put
    |> s3_request(bucket, key, put_opts(opts, query: query, body: body))
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize()
      |> Map.new()
    end)
  end

  defp do_list_parts(bucket, key, upload_id, part_number_marker, opts) do
    query = maybe_put_query(%{"uploadId" => upload_id}, "part-number-marker", part_number_marker)

    :get
    |> s3_request(bucket, key, Keyword.put(opts, :query, query))
    |> deserialize_response(opts, fn %{body: body} ->
      XMLParser.parse_list_parts(body)
    end)
  end

  defp do_copy_part(
         dest_bucket,
         dest_key,
         src_bucket,
         src_key,
         upload_id,
         part_number,
         src_range,
         opts
       ) do
    query = %{"uploadId" => upload_id, "partNumber" => to_string(part_number)}

    headers = [
      {"x-amz-copy-source", copy_source(src_bucket, src_key)},
      {"x-amz-copy-source-range", range_header(src_range)}
    ]

    :put
    |> s3_request(
      dest_bucket,
      dest_key,
      put_opts(opts, query: query, body: "", headers: headers)
    )
    |> deserialize_response(opts, fn %{body: body} ->
      XMLParser.parse_copy_part(body)
    end)
  end

  defp do_copy_parts(
         dest_bucket,
         dest_key,
         src_bucket,
         src_key,
         upload_id,
         content_length,
         opts
       ) do
    content_byte_stream_opts = opts[:content_byte_stream] || []
    content_byte_range_index = content_byte_stream_opts[:byte_range_index] || 0
    content_chunk_size = content_byte_stream_opts[:chunk_size] || @sixty_four_mib

    async_stream_opts =
      content_byte_stream_opts
      |> Keyword.take([:max_concurrency, :timeout, :on_timeout])
      |> Keyword.put_new(:max_concurrency, System.schedulers_online())
      |> Keyword.put(:ordered, false)

    content_byte_range_index
    |> Multipart.content_byte_stream(content_length, content_chunk_size)
    |> Stream.with_index(1)
    |> Task.async_stream(
      fn {{start_byte, end_byte}, part_num} ->
        copy_part_range(
          dest_bucket,
          dest_key,
          src_bucket,
          src_key,
          upload_id,
          part_num,
          {start_byte, end_byte, content_length},
          opts
        )
      end,
      async_stream_opts
    )
    |> handle_async_stream_response()
  end

  defp do_copy_object_multipart(dest_bucket, dest_key, src_bucket, src_key, opts) do
    with {:ok, info} <- head_object(src_bucket, src_key, opts),
         {:ok, mpu} <- create_multipart_upload(dest_bucket, dest_key, opts),
         content_length = String.to_integer(info.content_length),
         {:ok, parts} <-
           copy_parts(
             dest_bucket,
             dest_key,
             src_bucket,
             src_key,
             mpu.upload_id,
             content_length,
             opts
           ) do
      parts =
        parts
        |> Enum.map(fn {%{etag: etag}, part_num} -> {part_num, etag} end)
        |> Enum.sort()

      complete_multipart_upload(
        dest_bucket,
        dest_key,
        mpu.upload_id,
        parts,
        opts
      )
    end
  end

  defp do_complete_multipart_upload(bucket, key, upload_id, parts, opts) do
    with :ok <- validate_multipart_size(bucket, key, upload_id, opts) do
      xml = build_complete_multipart_xml(validate_parts!(parts))
      query = %{"uploadId" => upload_id}
      headers = [{"content-type", "application/xml"}]

      :post
      |> s3_request(bucket, key, put_opts(opts, query: query, body: xml, headers: headers))
      |> deserialize_response(
        opts,
        &deserialize_completed_multipart(&1, bucket, key, upload_id, opts)
      )
    end
  end

  defp deserialize_completed_multipart(%{body: body}, bucket, key, upload_id, opts) do
    with :ok <- validate_multipart_content_type(bucket, key, upload_id, opts) do
      XMLParser.parse_complete_multipart(body)
    end
  end

  defp build_complete_multipart_xml(parts) do
    parts_xml =
      Enum.map_join(parts, "", fn {num, etag} ->
        "<Part><PartNumber>#{num}</PartNumber><ETag>#{etag}</ETag></Part>"
      end)

    "<CompleteMultipartUpload>#{parts_xml}</CompleteMultipartUpload>"
  end

  defp do_enable_event_bridge(bucket, opts) do
    with {:ok, xml} <- get_raw_notification_xml(bucket, opts) do
      if String.contains?(xml, "EventBridgeConfiguration") do
        {:ok, %{}}
      else
        xml = expand_self_closing_notification(xml)
        new_xml = insert_event_bridge_config(xml)
        put_notification_xml(bucket, new_xml, opts)
      end
    end
  end

  defp do_disable_event_bridge(bucket, opts) do
    with {:ok, xml} <- get_raw_notification_xml(bucket, opts) do
      if String.contains?(xml, "EventBridgeConfiguration") do
        new_xml = remove_event_bridge_config(xml)
        put_notification_xml(bucket, new_xml, opts)
      else
        {:ok, %{}}
      end
    end
  end

  defp do_get_notification_configuration(bucket, opts) do
    with {:ok, xml} <- get_raw_notification_xml(bucket, opts) do
      {:ok, XMLParser.parse_notification_configuration(xml)}
    end
  end

  defp get_raw_notification_xml(bucket, opts) do
    case s3_request(:get, bucket, nil, Keyword.put(opts, :query, %{"notification" => ""})) do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, _} = error -> normalize_notification_error(error, opts)
    end
  end

  defp put_notification_xml(bucket, xml, opts) do
    md5 = :md5 |> :crypto.hash(xml) |> Base.encode64()

    headers = [
      {"content-md5", md5},
      {"content-type", "application/xml"}
    ]

    case s3_request(
           :put,
           bucket,
           nil,
           put_opts(opts, query: %{"notification" => ""}, body: xml, headers: headers)
         ) do
      {:ok, _} -> {:ok, %{}}
      {:error, _} = error -> normalize_notification_error(error, opts)
    end
  end

  defp normalize_notification_error({:error, {:http_error, status, resp}}, opts)
       when status in 400..499 do
    {:error, Error.not_found("resource not found.", %{response: resp}, opts)}
  end

  defp normalize_notification_error({:error, {:http_error, status, resp}}, opts)
       when status >= 500 do
    {:error,
     Error.service_unavailable("service temporarily unavailable", %{response: resp}, opts)}
  end

  defp normalize_notification_error({:error, reason}, opts) do
    {:error, Error.internal_server_error("internal server error", %{reason: reason}, opts)}
  end

  defp insert_event_bridge_config(xml) do
    String.replace(
      xml,
      "</NotificationConfiguration>",
      "<EventBridgeConfiguration/></NotificationConfiguration>"
    )
  end

  defp remove_event_bridge_config(xml) do
    String.replace(
      xml,
      ~r/<EventBridgeConfiguration\s*\/?>(\s*<\/EventBridgeConfiguration>)?/,
      ""
    )
  end

  defp expand_self_closing_notification(xml) do
    String.replace(
      xml,
      ~r/<NotificationConfiguration\s*\/>/,
      "<NotificationConfiguration></NotificationConfiguration>"
    )
  end

  defp do_put_public_access_block(bucket, opts) do
    xml = XMLBuilder.build_public_access_block(opts)
    put_bucket_config(bucket, "publicAccessBlock", xml, opts)
  end

  defp do_put_bucket_encryption(bucket, opts) do
    xml = XMLBuilder.build_bucket_encryption(opts)
    put_bucket_config(bucket, "encryption", xml, opts)
  end

  defp do_put_bucket_lifecycle_configuration(bucket, rules, opts) do
    xml = XMLBuilder.build_lifecycle_configuration(rules)
    put_bucket_config(bucket, "lifecycle", xml, opts)
  end

  defp put_bucket_config(bucket, query_key, xml, opts) do
    headers = xml_body_headers(xml)
    request_opts = put_opts(opts, query: %{query_key => ""}, body: xml, headers: headers)

    :put
    |> s3_request(bucket, nil, request_opts)
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize()
      |> Map.new()
    end)
  end

  defp xml_body_headers(xml) do
    md5 = :md5 |> :crypto.hash(xml) |> Base.encode64()
    [{"content-md5", md5}, {"content-type", "application/xml"}]
  end

  defp deserialize_response({:ok, response}, _opts, func) do
    case func.(response) do
      {:error, _} = error -> error
      {:ok, _} = ok -> ok
      result -> {:ok, result}
    end
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code in 300..399 do
    {:error, Error.bad_request("redirect not followed.", %{response: response}, opts)}
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code in 400..499 do
    {:error, Error.not_found("resource not found.", %{response: response}, opts)}
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code >= 500 do
    {:error,
     Error.service_unavailable("service temporarily unavailable", %{response: response}, opts)}
  end

  defp deserialize_response({:error, reason}, opts, _func) do
    {:error, Error.internal_server_error("internal server error", %{reason: reason}, opts)}
  end

  defp copy_part_range(
         dest_bucket,
         dest_key,
         src_bucket,
         src_key,
         upload_id,
         part_num,
         {start_byte, end_byte, _content_length},
         opts
       ) do
    case copy_part(
           dest_bucket,
           dest_key,
           src_bucket,
           src_key,
           upload_id,
           part_num,
           Range.new(start_byte, end_byte),
           opts
         ) do
      {:ok, result} -> {:ok, {result, part_num}}
      {:error, term} -> {:error, {term, part_num}}
    end
  end

  defp handle_async_stream_response(results) do
    results
    |> Enum.reduce({[], []}, fn
      {:ok, {:ok, result}}, {results, errors} ->
        {[result | results], errors}

      {:ok, {:error, reason}}, {results, errors} ->
        {results, [reason | errors]}

      {:exit, reason}, {results, errors} ->
        err = Error.internal_server_error("task exited", %{reason: reason}, [])
        {results, [err | errors]}
    end)
    |> then(fn
      {results, []} -> {:ok, Enum.reverse(results)}
      {_, errors} -> {:error, Enum.reverse(errors)}
    end)
  end

  defp validate_multipart_size(bucket, key, upload_id, opts) do
    case Keyword.get(opts, :max_size, @one_gib) do
      :infinity -> :ok
      false -> :ok
      nil -> :ok
      max -> check_multipart_size(bucket, key, upload_id, max, opts)
    end
  end

  defp check_multipart_size(bucket, key, upload_id, max, opts) do
    with {:ok, size} <- aggregate_object_size(bucket, key, upload_id, opts) do
      if size > max do
        abort_with_size_error(bucket, key, upload_id, max, opts)
      else
        :ok
      end
    end
  end

  defp abort_with_size_error(bucket, key, upload_id, max, opts) do
    abort_multipart_upload(bucket, key, upload_id, opts)

    {:error,
     Error.forbidden(
       "multipart upload size exceeds maximum allowed size",
       %{
         bucket: bucket,
         key: key,
         upload_id: upload_id,
         max_size: max
       },
       opts
     )}
  end

  defp aggregate_object_size(bucket, key, upload_id, opts) do
    do_aggregate_object_size(bucket, key, upload_id, nil, 0, opts)
  end

  defp do_aggregate_object_size(bucket, key, upload_id, part_number_marker, acc, opts) do
    case list_parts(bucket, key, upload_id, part_number_marker, opts) do
      {:ok, %{parts: parts} = body} ->
        size = Enum.reduce(parts, 0, fn p, sum -> sum + part_size(p.size) end)
        acc2 = acc + size

        if body.is_truncated do
          do_aggregate_object_size(
            bucket,
            key,
            upload_id,
            body.next_part_number_marker,
            acc2,
            opts
          )
        else
          {:ok, acc2}
        end

      {:error, _} = error ->
        error
    end
  end

  defp part_size(nil), do: 0
  defp part_size(size) when is_integer(size), do: size
  defp part_size(size) when is_binary(size) and size !== "", do: String.to_integer(size)
  defp part_size(_), do: 0

  defp validate_multipart_content_type(bucket, key, upload_id, opts) do
    case Keyword.get(opts, :content_type) do
      nil -> :ok
      :any -> :ok
      content_type -> check_content_type(bucket, key, upload_id, content_type, opts)
    end
  end

  defp check_content_type(bucket, key, upload_id, content_type, opts) do
    with {:ok, meta} <- head_object(bucket, key, opts) do
      if content_type_match?(content_type, meta.content_type) do
        :ok
      else
        handle_content_type_mismatch(bucket, key, upload_id, content_type, opts)
      end
    end
  end

  defp handle_content_type_mismatch(bucket, key, upload_id, content_type, opts) do
    error =
      {:error,
       Error.forbidden(
         "content type mismatch",
         %{
           bucket: bucket,
           key: key,
           upload_id: upload_id,
           content_type: content_type
         },
         opts
       )}

    case Keyword.get(opts, :on_content_type_mismatch, :delete) do
      :delete -> with {:ok, _} <- delete_object(bucket, key, opts), do: error
      :error -> error
    end
  end

  defp content_type_match?(regex, pattern) when is_struct(regex, Regex) do
    Regex.match?(regex, pattern)
  end

  defp content_type_match?(str, pattern) when is_binary(str) do
    str =~ pattern
  end

  defp validate_parts!(entries) do
    Enum.map(entries, fn
      {part, etag} when is_integer(part) and is_binary(etag) ->
        {part, etag}

      {part, etag} when is_binary(part) and is_binary(etag) ->
        {String.to_integer(part), etag}

      failed_value ->
        raise ArgumentError, """
        Expected parts parameters to be a list of `{part_number :: integer(), etag :: binary()}`

        failed_value:

        #{inspect(failed_value)}

        entries:

        #{inspect(entries)}
        """
    end)
  end

  defp to_http_date(datetime) do
    datetime
    |> DateTime.to_unix(:second)
    |> DateTime.from_unix!()
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")
  end

  # --- Opt / header helpers --------------------------------------------------

  # Merge caller opts with per-operation keys; per-op values win (the most
  # recent call to `put_opts` decides).
  defp put_opts(opts, extra), do: Keyword.merge(opts, extra)

  defp maybe_put_query(query, _key, nil), do: query
  defp maybe_put_query(query, _key, ""), do: query
  defp maybe_put_query(query, key, value), do: Map.put(query, key, to_string(value))

  defp object_headers(opts) do
    explicit = Keyword.get(opts, :headers, [])

    explicit
    |> maybe_add_header("content-type", opts[:content_type])
    |> maybe_add_header("x-amz-acl", opts[:acl])
  end

  defp maybe_add_header(headers, _key, nil), do: headers
  defp maybe_add_header(headers, key, value), do: [{key, to_string(value)} | headers]

  defp copy_source(src_bucket, src_key) do
    "/" <> src_bucket <> "/" <> src_key
  end

  defp range_header(first..last//_step) do
    "bytes=#{first}-#{last}"
  end

  defp signer_creds(config) do
    %{
      access_key_id: config.access_key_id,
      secret_access_key: config.secret_access_key,
      token: config.security_token,
      region: config.region,
      service: @service,
      now: DateTime.utc_now()
    }
  end

  # -- Operation build + dispatch ---------------------------------------------

  defp s3_request(method, bucket, key, opts) do
    with {:ok, op} <- build_operation(method, bucket, key, opts) do
      Client.execute(op)
    end
  end

  defp apply_overrides(op, overrides) do
    Enum.reduce(@override_keys, op, fn key, acc ->
      case Keyword.fetch(overrides, key) do
        {:ok, value} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # PRIVATE HELPERS
  # ---------------------------------------------------------------------------

  defp build_base_path(nil, nil), do: "/"
  defp build_base_path(nil, key), do: "/" <> encode_key(key)
  defp build_base_path(prefix, nil), do: "/" <> prefix
  defp build_base_path(prefix, key), do: "/" <> prefix <> "/" <> encode_key(key)

  defp port_suffix(_scheme, nil), do: ""
  defp port_suffix("https", 443), do: ""
  defp port_suffix("http", 80), do: ""
  defp port_suffix(_scheme, port), do: ":#{port}"

  defp build_query_part(query) do
    case encode_query(query) do
      "" -> ""
      qs -> "?" <> qs
    end
  end

  defp address(%{path_style: true, host: host}, bucket) do
    case bucket do
      nil -> {host, nil}
      b -> {host, b}
    end
  end

  defp address(%{host: host}, nil), do: {host, nil}
  defp address(%{host: host}, bucket), do: {"#{bucket}.#{host}", nil}

  defp encode_key(key) do
    key
    |> String.split("/")
    |> Enum.map_join("/", fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
  end

  defp encode_query(map) when map_size(map) === 0, do: ""

  defp encode_query(map) when is_map(map) or is_list(map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
    |> Enum.sort()
    |> Enum.map_join("&", fn
      {k, ""} ->
        URI.encode(k, &URI.char_unreserved?/1)

      {k, v} ->
        "#{URI.encode(k, &URI.char_unreserved?/1)}=#{URI.encode(v, &URI.char_unreserved?/1)}"
    end)
  end

  defp classify_body(""), do: {nil, false}
  defp classify_body(body) when is_binary(body), do: {nil, false}

  defp classify_body(body) when is_list(body) do
    if iodata?(body), do: {nil, false}, else: {"UNSIGNED-PAYLOAD", true}
  end

  defp classify_body(%Stream{}), do: {"UNSIGNED-PAYLOAD", true}
  defp classify_body(%{}), do: {"UNSIGNED-PAYLOAD", true}
  defp classify_body(body) when is_function(body), do: {"UNSIGNED-PAYLOAD", true}
  defp classify_body(_body), do: {nil, false}

  defp iodata?(list) do
    _ = IO.iodata_length(list)
    true
  rescue
    _ -> false
  end

  defp resolve_path_style(nil, sandbox_opts), do: Client.sandbox_local?(sandbox_opts)
  defp resolve_path_style(value, _sandbox_opts), do: value

  # ---------------------------------------------------------------------------
  # SANDBOX HELPERS
  # ---------------------------------------------------------------------------

  defp inline_sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    cfg = Config.sandbox()
    sandbox_enabled = sandbox_opts[:enabled] || cfg[:enabled]
    sandbox_mode = sandbox_opts[:mode] || cfg[:mode]

    sandbox_enabled and sandbox_mode === :inline and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    @doc false
    defdelegate sandbox_disabled?, to: AWS.S3.Sandbox

    @doc false
    defdelegate sandbox_list_buckets_response(opts),
      to: AWS.S3.Sandbox,
      as: :list_buckets_response

    @doc false
    defdelegate sandbox_create_bucket_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :create_bucket_response

    @doc false
    defdelegate sandbox_delete_bucket_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :delete_bucket_response

    @doc false
    defdelegate sandbox_put_object_response(bucket, key, body, opts),
      to: AWS.S3.Sandbox,
      as: :put_object_response

    @doc false
    defdelegate sandbox_head_object_response(bucket, key, opts),
      to: AWS.S3.Sandbox,
      as: :head_object_response

    @doc false
    defdelegate sandbox_delete_object_response(bucket, key, opts),
      to: AWS.S3.Sandbox,
      as: :delete_object_response

    @doc false
    defdelegate sandbox_get_object_response(bucket, key, opts),
      to: AWS.S3.Sandbox,
      as: :get_object_response

    @doc false
    defdelegate sandbox_list_objects_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :list_objects_response

    @doc false
    defdelegate sandbox_copy_object_response(dest_bucket, dest_key, src_bucket, src_key, opts),
      to: AWS.S3.Sandbox,
      as: :copy_object_response

    @doc false
    defdelegate sandbox_presign_response(bucket, http_method, key, opts),
      to: AWS.S3.Sandbox,
      as: :presign_response

    @doc false
    defdelegate sandbox_presign_post_response(bucket, key, opts),
      to: AWS.S3.Sandbox,
      as: :presign_post_response

    @doc false
    defdelegate sandbox_presign_part_response(bucket, object, upload_id, part_number, opts),
      to: AWS.S3.Sandbox,
      as: :presign_part_response

    @doc false
    defdelegate sandbox_create_multipart_upload_response(bucket, key, opts),
      to: AWS.S3.Sandbox,
      as: :create_multipart_upload_response

    @doc false
    defdelegate sandbox_abort_multipart_upload_response(bucket, key, upload_id, opts),
      to: AWS.S3.Sandbox,
      as: :abort_multipart_upload_response

    @doc false
    defdelegate sandbox_upload_part_response(bucket, key, upload_id, part_number, body, opts),
      to: AWS.S3.Sandbox,
      as: :upload_part_response

    @doc false
    defdelegate sandbox_list_parts_response(bucket, key, upload_id, part_number_marker, opts),
      to: AWS.S3.Sandbox,
      as: :list_parts_response

    @doc false
    defdelegate sandbox_copy_part_response(
                  dest_bucket,
                  dest_key,
                  src_bucket,
                  src_key,
                  upload_id,
                  part_number,
                  src_range,
                  opts
                ),
                to: AWS.S3.Sandbox,
                as: :copy_part_response

    @doc false
    defdelegate sandbox_copy_parts_response(
                  dest_bucket,
                  dest_key,
                  src_bucket,
                  src_key,
                  upload_id,
                  content_length,
                  opts
                ),
                to: AWS.S3.Sandbox,
                as: :copy_parts_response

    @doc false
    defdelegate sandbox_complete_multipart_upload_response(
                  bucket,
                  key,
                  upload_id,
                  parts,
                  opts
                ),
                to: AWS.S3.Sandbox,
                as: :complete_multipart_upload_response

    # S3 EventBridge notification sandbox delegates
    @doc false
    defdelegate sandbox_enable_event_bridge_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :enable_event_bridge_response

    @doc false
    defdelegate sandbox_disable_event_bridge_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :disable_event_bridge_response

    @doc false
    defdelegate sandbox_get_notification_configuration_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :get_notification_configuration_response

    @doc false
    defdelegate sandbox_head_bucket_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :head_bucket_response

    @doc false
    defdelegate sandbox_put_public_access_block_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :put_public_access_block_response

    @doc false
    defdelegate sandbox_put_bucket_encryption_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :put_bucket_encryption_response

    @doc false
    defdelegate sandbox_put_bucket_lifecycle_configuration_response(bucket, rules, opts),
      to: AWS.S3.Sandbox,
      as: :put_bucket_lifecycle_configuration_response
  else
    defp sandbox_disabled?, do: true

    defp sandbox_list_buckets_response(opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      options: #{inspect(opts)}
      """
    end

    defp sandbox_create_bucket_response(bucket, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_delete_bucket_response(bucket, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_put_object_response(bucket, key, body, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      key: #{inspect(key)}
      body: #{inspect(body)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_head_object_response(bucket, key, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      key: #{inspect(key)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_delete_object_response(bucket, key, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      key: #{inspect(key)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_get_object_response(bucket, key, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      key: #{inspect(key)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_list_objects_response(bucket, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_copy_object_response(dest_bucket, dest_key, src_bucket, src_key, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      dest_bucket: #{inspect(dest_bucket)}
      dest_key: #{inspect(dest_key)}
      src_bucket: #{inspect(src_bucket)}
      src_key: #{inspect(src_key)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_presign_response(bucket, http_method, key, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      http_method: #{inspect(http_method)}
      key: #{inspect(key)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_presign_post_response(bucket, key, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      key: #{inspect(key)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_presign_part_response(bucket, object, upload_id, part_number, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      part_number: #{inspect(part_number)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_create_multipart_upload_response(bucket, key, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      key: #{inspect(key)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_abort_multipart_upload_response(bucket, key, upload_id, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      key: #{inspect(key)}
      upload_id: #{inspect(upload_id)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_upload_part_response(bucket, key, upload_id, part_number, body, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      key: #{inspect(key)}
      upload_id: #{inspect(upload_id)}
      part_number: #{inspect(part_number)}
      body: #{inspect(body)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_list_parts_response(bucket, key, upload_id, part_number_marker, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      key: #{inspect(key)}
      upload_id: #{inspect(upload_id)}
      part_number_marker: #{inspect(part_number_marker)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_copy_part_response(
           dest_bucket,
           dest_key,
           src_bucket,
           src_key,
           upload_id,
           part_number,
           src_range,
           opts
         ) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      dest_bucket: #{inspect(dest_bucket)}
      dest_key: #{inspect(dest_key)}
      src_bucket: #{inspect(src_bucket)}
      src_key: #{inspect(src_key)}
      upload_id: #{inspect(upload_id)}
      part_number: #{inspect(part_number)}
      src_range: #{inspect(src_range)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_copy_parts_response(
           dest_bucket,
           dest_key,
           src_bucket,
           src_key,
           upload_id,
           content_length,
           opts
         ) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      dest_bucket: #{inspect(dest_bucket)}
      dest_key: #{inspect(dest_key)}
      src_bucket: #{inspect(src_bucket)}
      src_key: #{inspect(src_key)}
      upload_id: #{inspect(upload_id)}
      content_length: #{inspect(content_length)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_complete_multipart_upload_response(bucket, key, upload_id, parts, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      key: #{inspect(key)}
      upload_id: #{inspect(upload_id)}
      parts: #{inspect(parts)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_enable_event_bridge_response(bucket, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_disable_event_bridge_response(bucket, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_get_notification_configuration_response(bucket, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_head_bucket_response(bucket, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_put_public_access_block_response(bucket, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_put_bucket_encryption_response(bucket, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      options: #{inspect(opts)}
      """
    end

    defp sandbox_put_bucket_lifecycle_configuration_response(bucket, rules, opts) do
      raise """
      Cannot use inline sandbox mode outside of test environment.

      bucket: #{inspect(bucket)}
      rules: #{inspect(rules)}
      options: #{inspect(opts)}
      """
    end
  end
end
