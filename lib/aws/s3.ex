defmodule AWS.S3 do
  @moduledoc """
  `AWS.S3` provides an API for with S3 (Simple Storage Service).

  This API is a wrapper for `ExAws.S3`. It also provides consistent error
  handling, response deserialization, and sandbox support for local
  development and testing.

  ## Shared Options

  The following options are available for most functions in this API:

    - `:region` - The AWS region where the bucket will be created. Defaults to `AWS.Config.region()`.

    - `:s3` - A keyword list of options used to configure the `ExAws.S3` API. See `ExAws.Config.new/2` for available options.

    - `:sandbox` - A keyword list to override sandbox configuration.
        - `:enabled` - Whether sandbox mode is enabled. Defaults to `AWS.Config.sandbox_enabled()`.
        - `:mode` - Controls whether the sandbox uses an emulated service or an OTP process.
          - When the mode is `:local`, the sandbox makes HTTP calls to a sandboxed service such as localstack.
          - When the mode is `:inline`, the sandbox uses an OTP process to handle requests.
        - `:scheme` - The sandbox scheme. Defaults to `AWS.Config.sandbox_scheme()`.
        - `:host` - The sandbox host. Defaults to `AWS.Config.sandbox_host()`.
        - `:port` - The sandbox port. Defaults to `AWS.Config.sandbox_port()`.

  ## Sandbox

  The sandbox allows you to mock S3 operations in tests without making real
  AWS or LocalStack calls. Set `sandbox: [enabled: true, mode: :inline]` to
  activate inline sandbox mode.

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
    Config,
    Error,
    S3.Multipart,
    S3.XMLParser,
    Serializer
  }

  alias ExAws.S3, as: API

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
  See `ExAws.S3.put_bucket/3` for available options.

  ## Examples

      iex> AWS.S3.list_buckets()
      {:ok, [%{name: "my-bucket", creation_date: "2023-01-01T00:00:00.000Z"}]}
  """
  @spec list_buckets(opts :: keyword()) :: {:ok, map()} | {:error, term()}
  def list_buckets(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_buckets_response(opts)
    else
      call_list_buckets(opts)
    end
  end

  defp call_list_buckets(opts) do
    opts
    |> Keyword.get(:operation, [])
    |> API.list_buckets()
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: %{buckets: buckets}} ->
      Serializer.deserialize(buckets, opts)
    end)
  end

  @doc """
  Creates a bucket in the specified region.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:CreateBucket

  ## Arguments

    * `bucket` - The name of the bucket to create.
    * `region` - The AWS region where the bucket will be created (e.g., "us-east-1", "us-west-2").
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.
  See `ExAws.S3.put_bucket/3` for available options.

  ## Examples

      iex> AWS.S3.create_bucket("my-bucket")
      {:ok, [{"x-amz-id-2", "..."}, {"x-amz-request-id", "..."}]}

      iex> AWS.S3.create_bucket("my-bucket", sandbox: [enabled: true, mode: :local])
      {:ok, [{"x-amz-id-2", "..."}, {"x-amz-request-id", "..."}]}
  """
  @spec create_bucket(bucket :: binary(), opts :: keyword()) ::
          {:ok, list()} | {:error, term()}
  def create_bucket(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_bucket_response(bucket, opts)
    else
      call_create_bucket(bucket, opts)
    end
  end

  defp call_create_bucket(bucket, opts) do
    region = opts[:region] || Config.region()

    bucket
    |> API.put_bucket(region, opts)
    |> perform(opts)
    |> deserialize_response(opts, fn
      %{headers: headers} ->
        headers
        |> Serializer.deserialize(opts)
        |> Map.new()
    end)
    |> translate_error(fn
      %{details: %{response: %{status_code: 409}}} ->
        {
          :error,
          Error.conflict(
            "bucket already exists",
            %{
              bucket: bucket,
              region: region
            },
            opts
          )
        }

      error ->
        error
    end)
  end

  @doc """
  Uploads an object to a bucket.

  ## Permissions

  To execute this request, you must have the following permission:

    - s3:PutObject

  ## Arguments

    * `bucket` - The name of the bucket to upload to.
    * `key` - The key under which to store the object.
    * `body` - The content to upload.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.
  See `ExAws.S3.put_object/4` for available options.

  ## Examples

      iex> AWS.S3.put_object("my-bucket", "my-key", "hello world")
      {:ok, %{etag: "...", x_amz_request_id: "..."}}
  """
  @spec put_object(bucket :: binary(), key :: binary(), body :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def put_object(bucket, key, body, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_object_response(bucket, key, body, opts)
    else
      call_put_object(bucket, key, body, opts)
    end
  end

  defp call_put_object(bucket, key, body, opts) do
    bucket
    |> API.put_object(key, body, opts)
    |> perform(opts)
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize(opts)
      |> Map.new()
    end)
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
  See `ExAws.S3.head_object/3` for available options.

  ## Examples

      iex> AWS.S3.head_object("my-bucket", "my-key")
      {:ok, %{content_length: 1234, content_type: "application/json", ...}}
  """
  @spec head_object(bucket :: binary(), key :: binary(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def head_object(bucket, key, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_head_object_response(bucket, key, opts)
    else
      call_head_object(bucket, key, opts)
    end
  end

  defp call_head_object(bucket, key, opts) do
    bucket
    |> API.head_object(key, opts)
    |> perform(opts)
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize(opts)
      |> Map.new()
    end)
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
  See `ExAws.S3.delete_object/3` for available options.

  ## Examples

      iex> AWS.S3.delete_object("my-bucket", "my-key")
      {:ok, %{}}
  """
  @spec delete_object(bucket :: binary(), key :: binary(), opts :: keyword()) ::
          {:ok, term()} | {:error, term()}
  def delete_object(bucket, key, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_object_response(bucket, key, opts)
    else
      call_delete_object(bucket, key, opts)
    end
  end

  defp call_delete_object(bucket, key, opts) do
    bucket
    |> API.delete_object(key, opts)
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      Serializer.deserialize(body, opts)
    end)
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
  See `ExAws.S3.get_object/3` for available options.

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
      call_get_object(bucket, key, opts)
    end
  end

  defp call_get_object(bucket, key, opts) do
    bucket
    |> API.get_object(key, opts)
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      body
    end)
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

  See the "Shared Options" section in the module documentation for common options.
  See `ExAws.S3.list_objects_v2/2` for available options.

  ## Examples

      iex> AWS.S3.list_objects("my-bucket")
      {:ok, [%{key: "my-key", size: 1234, ...}]}
  """
  @spec list_objects(bucket :: binary(), opts :: keyword()) ::
          {:ok, list()} | {:error, term()}
  def list_objects(bucket, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_objects_response(bucket, opts)
    else
      call_list_objects(bucket, opts)
    end
  end

  defp call_list_objects(bucket, opts) do
    bucket
    |> API.list_objects_v2(opts)
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: %{contents: contents}} ->
      Serializer.deserialize(contents, opts)
    end)
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
  See `ExAws.S3.put_object_copy/5` for available options.

  ## Examples

      iex> AWS.S3.copy_object("dest-bucket", "dest-key", "src-bucket", "src-key")
      {:ok, %{copy_object_result: %{etag: "...", last_modified: "..."}}}
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
      call_copy_object(dest_bucket, dest_key, src_bucket, src_key, opts)
    end
  end

  defp call_copy_object(dest_bucket, dest_key, src_bucket, src_key, opts) do
    dest_bucket
    |> API.put_object_copy(dest_key, src_bucket, src_key, opts)
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      XMLParser.parse_copy_object_result(body)
    end)
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
      call_presign(bucket, http_method, key, opts)
    end
  end

  defp call_presign(bucket, http_method, key, opts) do
    expires_in = opts[:expires_in] || @sixty_seconds
    opts = Keyword.put(opts, :expires_in, expires_in)

    case opts |> s3_config() |> API.presigned_url(http_method, bucket, key, opts) do
      {:ok, url} ->
        %{
          key: key,
          url: url,
          expires_in: expires_in,
          expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
        }

      {:error, reason} ->
        raise "Failed to generate presigned URL for object: #{inspect(reason)}"
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
    * `:virtual_host` - Whether to use virtual hosted-style URLs. Defaults to false.
    * `:s3_accelerate` - Whether to use S3 Transfer Acceleration. Defaults to false.
    * `:bucket_as_host` - Whether to use the bucket name as host. Defaults to false.
    * `:content_type` - Optional content type prefix for the upload condition.
    * `:acl_conditions` - Optional ACL conditions for the upload.
    * `:key_conditions` - Optional key conditions for the upload.

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
      call_presign_post(bucket, key, opts)
    end
  end

  defp call_presign_post(bucket, key, opts) do
    expires_in = opts[:expires_in] || @sixty_seconds
    min_size = Keyword.get(opts, :min_size, 0)
    max_size = Keyword.get(opts, :max_size, @one_gib)
    virtual_host? = Keyword.get(opts, :virtual_host, false)
    s3_accelerate? = Keyword.get(opts, :s3_accelerate, false)
    bucket_as_host? = Keyword.get(opts, :bucket_as_host, false)

    content_type_conditions =
      case Keyword.get(opts, :content_type) do
        nil -> []
        content_type -> ["starts-with", "$Content-Type", content_type]
      end

    opts
    |> s3_config()
    |> API.presigned_post(
      bucket,
      key,
      expires_in: expires_in,
      content_length_range: [min_size, max_size],
      acl: Keyword.get(opts, :acl_conditions),
      key: Keyword.get(opts, :key_conditions),
      custom_conditions: [content_type_conditions],
      virtual_host: virtual_host?,
      s3_accelerate: s3_accelerate?,
      bucket_as_host: bucket_as_host?
    )
    |> then(fn %{fields: fields, url: url} ->
      {:ok,
       %{
         fields: Serializer.deserialize(fields, opts),
         url: url,
         expires_in: expires_in,
         expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
       }}
    end)
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
      call_presign_part(bucket, object, upload_id, part_number, opts)
    end
  end

  defp call_presign_part(bucket, object, upload_id, part_number, opts) do
    query_params = %{"uploadId" => upload_id, "partNumber" => part_number}
    opts = Keyword.update(opts, :query_params, query_params, &Map.merge(&1, query_params))
    presign(bucket, :put, object, opts)
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
  See `ExAws.S3.initiate_multipart_upload/3` for available options.

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
      call_create_multipart_upload(bucket, key, opts)
    end
  end

  defp call_create_multipart_upload(bucket, key, opts) do
    one_min_from_now = DateTime.add(DateTime.utc_now(), 1, :minute)
    expiry = to_http_date(one_min_from_now)

    opts =
      Keyword.update(opts, :expires, expiry, fn
        nil -> expiry
        %DateTime{} = datetime -> to_http_date(datetime)
        expires -> expires
      end)

    bucket
    |> API.initiate_multipart_upload(key, opts)
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      Serializer.deserialize(body, opts)
    end)
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
      call_abort_multipart_upload(bucket, key, upload_id, opts)
    end
  end

  defp call_abort_multipart_upload(bucket, key, upload_id, opts) do
    bucket
    |> API.abort_multipart_upload(key, upload_id)
    |> perform(opts)
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize(opts)
      |> Map.new()
    end)
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
    * `body` - The content of the part.
    * `opts` - A keyword list of options.

  ## Options

  See the "Shared Options" section in the module documentation for common options.
  See `ExAws.S3.upload_part/6` for available options.

  ## Examples

      iex> AWS.S3.upload_part("my-bucket", "my-key", "upload-id", 1, "part-data")
      {:ok, %{etag: "...", ...}}
  """
  @spec upload_part(
          bucket :: binary(),
          key :: binary(),
          upload_id :: binary(),
          part_number :: integer(),
          body :: binary(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def upload_part(bucket, key, upload_id, part_number, body, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_upload_part_response(bucket, key, upload_id, part_number, body, opts)
    else
      call_upload_part(bucket, key, upload_id, part_number, body, opts)
    end
  end

  defp call_upload_part(bucket, key, upload_id, part_number, body, opts) do
    bucket
    |> API.upload_part(key, upload_id, part_number, body, opts)
    |> perform(opts)
    |> deserialize_response(opts, fn %{headers: headers} ->
      headers
      |> Serializer.deserialize(opts)
      |> Map.new()
    end)
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

    - `:part_number_marker` - Specifies the part after which listing should begin.

  See the "Shared Options" section in the module documentation for common options.
  See `ExAws.S3.list_parts/4` for available options.

  ## Examples

      iex> AWS.S3.list_parts("my-bucket", "my-key", "upload-id")
      {:ok, [%{part_number: 1, size: 5242880, etag: "..."}]}
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
      call_list_parts(bucket, key, upload_id, part_number_marker, opts)
    end
  end

  defp call_list_parts(bucket, key, upload_id, part_number_marker, opts) do
    list_parts_opts =
      if part_number_marker do
        query_params = %{"part-number-marker" => part_number_marker}
        Keyword.update(opts, :query_params, query_params, &Map.merge(&1, query_params))
      else
        Keyword.take(opts, [:query_params])
      end

    bucket
    |> API.list_parts(key, upload_id, list_parts_opts)
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      Serializer.deserialize(body, opts)
    end)
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
  See `ExAws.S3.upload_part_copy/8` for available options.

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
      call_copy_part(
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

  defp call_copy_part(
         dest_bucket,
         dest_key,
         src_bucket,
         src_key,
         upload_id,
         part_number,
         src_range,
         opts
       ) do
    dest_bucket
    |> API.upload_part_copy(
      dest_key,
      src_bucket,
      src_key,
      upload_id,
      part_number,
      src_range,
      opts
    )
    |> perform(opts)
    |> deserialize_response(opts, fn %{body: body} ->
      Serializer.deserialize(body, opts)
    end)
  end

  @doc """
  Copies parts of an object from one location to another using concurrent multipart copy operations.

  Partitions the source object into byte-range chunks and copies each chunk
  concurrently using `Task.async_stream/3`. Returns a sorted list of
  `{part_number, etag}` tuples on success.

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
      call_copy_parts(
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

  defp call_copy_parts(
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
    call_copy_object_multipart(dest_bucket, dest_key, src_bucket, src_key, opts)
  end

  defp call_copy_object_multipart(dest_bucket, dest_key, src_bucket, src_key, opts) do
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
      call_complete_multipart_upload(bucket, key, upload_id, parts, opts)
    end
  end

  defp call_complete_multipart_upload(bucket, key, upload_id, parts, opts) do
    with :ok <- validate_multipart_size(bucket, key, upload_id, opts) do
      bucket
      |> API.complete_multipart_upload(key, upload_id, validate_parts!(parts))
      |> perform(opts)
      |> deserialize_response(opts, fn %{body: body} ->
        with :ok <- validate_multipart_content_type(bucket, key, upload_id, opts) do
          Serializer.deserialize(body, opts)
        end
      end)
    end
  end

  # Sandbox helpers

  defp inline_sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    sandbox_enabled = sandbox_opts[:enabled] || Config.sandbox_enabled?()
    sandbox_mode = sandbox_opts[:mode] || Config.sandbox_mode()

    sandbox_enabled and sandbox_mode === :inline and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    defdelegate sandbox_disabled?, to: AWS.S3.Sandbox

    defdelegate sandbox_list_buckets_response(opts),
      to: AWS.S3.Sandbox,
      as: :list_buckets_response

    defdelegate sandbox_create_bucket_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :create_bucket_response

    defdelegate sandbox_put_object_response(bucket, key, body, opts),
      to: AWS.S3.Sandbox,
      as: :put_object_response

    defdelegate sandbox_head_object_response(bucket, key, opts),
      to: AWS.S3.Sandbox,
      as: :head_object_response

    defdelegate sandbox_delete_object_response(bucket, key, opts),
      to: AWS.S3.Sandbox,
      as: :delete_object_response

    defdelegate sandbox_get_object_response(bucket, key, opts),
      to: AWS.S3.Sandbox,
      as: :get_object_response

    defdelegate sandbox_list_objects_response(bucket, opts),
      to: AWS.S3.Sandbox,
      as: :list_objects_response

    defdelegate sandbox_copy_object_response(dest_bucket, dest_key, src_bucket, src_key, opts),
      to: AWS.S3.Sandbox,
      as: :copy_object_response

    defdelegate sandbox_presign_response(bucket, http_method, key, opts),
      to: AWS.S3.Sandbox,
      as: :presign_response

    defdelegate sandbox_presign_post_response(bucket, key, opts),
      to: AWS.S3.Sandbox,
      as: :presign_post_response

    defdelegate sandbox_presign_part_response(bucket, object, upload_id, part_number, opts),
      to: AWS.S3.Sandbox,
      as: :presign_part_response

    defdelegate sandbox_create_multipart_upload_response(bucket, key, opts),
      to: AWS.S3.Sandbox,
      as: :create_multipart_upload_response

    defdelegate sandbox_abort_multipart_upload_response(bucket, key, upload_id, opts),
      to: AWS.S3.Sandbox,
      as: :abort_multipart_upload_response

    defdelegate sandbox_upload_part_response(bucket, key, upload_id, part_number, body, opts),
      to: AWS.S3.Sandbox,
      as: :upload_part_response

    defdelegate sandbox_list_parts_response(bucket, key, upload_id, part_number_marker, opts),
      to: AWS.S3.Sandbox,
      as: :list_parts_response

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

    defdelegate sandbox_complete_multipart_upload_response(
                  bucket,
                  key,
                  upload_id,
                  parts,
                  opts
                ),
                to: AWS.S3.Sandbox,
                as: :complete_multipart_upload_response
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
  end

  defp perform(op, opts) do
    case ExAws.Operation.perform(op, s3_config(opts)) do
      {:ok, payload} -> {:ok, payload}
      {:error, reason} -> {:error, reason}
    end
  end

  defp s3_config(opts) do
    {s3_opts, opts} = Keyword.pop(opts, :s3, [])
    {sandbox_opts, opts} = Keyword.pop(opts, :sandbox, [])

    overrides =
      s3_opts
      |> Keyword.put_new(:region, opts[:region] || Config.region())
      |> configure_endpoint(sandbox_opts)

    ExAws.Config.new(:s3, overrides)
  end

  defp configure_endpoint(s3_opts, sandbox_opts) do
    sandbox_enabled = sandbox_opts[:enabled] || Config.sandbox_enabled?()
    sandbox_mode = sandbox_opts[:mode] || Config.sandbox_mode()

    if sandbox_enabled and sandbox_mode === :local do
      s3_opts
      |> Keyword.put(:scheme, Config.sandbox_scheme())
      |> Keyword.put(:host, Config.sandbox_host())
      |> Keyword.put(:port, Config.sandbox_port())
      |> Keyword.put_new(:access_key_id, "test")
      |> Keyword.put_new(:secret_access_key, "test")
    else
      maybe_put_credentials(s3_opts)
    end
  end

  defp maybe_put_credentials(opts) do
    opts
    |> Keyword.put_new(:access_key_id, Config.access_key_id())
    |> Keyword.put_new(:secret_access_key, Config.secret_access_key())
  end

  defp translate_error({:error, reason}, func), do: func.(reason)
  defp translate_error({:ok, _} = ok, _func), do: ok

  defp deserialize_response({:ok, response}, _opts, func) do
    case func.(response) do
      {:error, _} = error -> error
      {:ok, _} = ok -> ok
      result -> {:ok, result}
    end
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code in 300..399 do
    {
      :error,
      Error.bad_request(
        "redirect not followed.",
        %{response: response},
        opts
      )
    }
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code in 400..499 do
    {
      :error,
      Error.not_found(
        "resource not found.",
        %{response: response},
        opts
      )
    }
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code >= 500 do
    {
      :error,
      Error.service_unavailable(
        "service temporarily unavailable",
        %{response: response},
        opts
      )
    }
  end

  # fallback
  defp deserialize_response({:error, reason}, opts, _func) do
    {
      :error,
      Error.internal_server_error(
        "internal server error",
        %{reason: reason},
        opts
      )
    }
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
      :infinity ->
        :ok

      false ->
        :ok

      nil ->
        :ok

      max ->
        with {:ok, size} <- aggregate_object_size(bucket, key, upload_id, opts) do
          if size > max do
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
          else
            :ok
          end
        end
    end
  end

  defp aggregate_object_size(bucket, key, upload_id, opts) do
    call_aggregate_object_size(bucket, key, upload_id, nil, 0, opts)
  end

  defp call_aggregate_object_size(bucket, key, upload_id, part_number_marker, acc, opts) do
    case list_parts(bucket, key, upload_id, part_number_marker, opts) do
      {:ok, %{parts: parts} = body} ->
        size = Enum.reduce(parts, 0, fn p, sum -> sum + (p.size || 0) end)
        acc2 = acc + size

        if body.is_truncated do
          call_aggregate_object_size(
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

  defp validate_multipart_content_type(bucket, key, upload_id, opts) do
    case Keyword.get(opts, :content_type) do
      nil ->
        :ok

      :any ->
        :ok

      content_type ->
        with {:ok, meta} <- head_object(bucket, key, opts) do
          if content_type_match?(content_type, meta.content_type) do
            :ok
          else
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
        end
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
end
