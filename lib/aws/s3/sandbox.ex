if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AWS.S3.Sandbox do
    @moduledoc false

    @registry :aws_s3_sandbox
    @state "state"
    @disabled "disabled"
    @sleep 10
    @keys :unique

    @doc """
    Starts the sandbox.
    """
    def start_link do
      Registry.start_link(keys: @keys, name: @registry)
    end

    # Response retrieval functions

    @doc """
    Returns the registered response function for `list_buckets/1` in the
    context of the calling process.
    """
    def list_buckets_response(opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (options) -> ..."
        ]

      func = find!(:list_buckets, "*", doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `create_bucket/2` in the
    context of the calling process.
    """
    def create_bucket_response(bucket, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (options) -> ..."
        ]

      func = find!(:create_bucket, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `delete_bucket/2` in the
    context of the calling process.
    """
    def delete_bucket_response(bucket, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (options) -> ..."
        ]

      func = find!(:delete_bucket, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `put_object/4` in the
    context of the calling process.
    """
    def put_object_response(bucket, key, body, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (key) -> ...",
          "fn (key, body) -> ...",
          "fn (key, body, options) -> ..."
        ]

      func = find!(:put_object, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(key)
        2 -> func.(key, body)
        3 -> func.(key, body, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `head_object/3` in the
    context of the calling process.
    """
    def head_object_response(bucket, key, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (key) -> ...",
          "fn (key, options) -> ..."
        ]

      func = find!(:head_object, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(key)
        2 -> func.(key, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `delete_object/3` in the
    context of the calling process.
    """
    def delete_object_response(bucket, key, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (key) -> ...",
          "fn (key, options) -> ..."
        ]

      func = find!(:delete_object, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(key)
        2 -> func.(key, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `get_object/3` in the
    context of the calling process.
    """
    def get_object_response(bucket, key, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (key) -> ...",
          "fn (key, options) -> ..."
        ]

      func = find!(:get_object, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(key)
        2 -> func.(key, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `list_objects/2` in the
    context of the calling process.
    """
    def list_objects_response(bucket, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (bucket) -> ...",
          "fn (bucket, options) -> ..."
        ]

      func = find!(:list_objects, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(bucket)
        2 -> func.(bucket, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `copy_object/5` in the
    context of the calling process.
    """
    def copy_object_response(dest_bucket, dest_key, src_bucket, src_key, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (dest_key) -> ...",
          "fn (dest_key, src_bucket) -> ...",
          "fn (dest_key, src_bucket, src_key) -> ...",
          "fn (dest_key, src_bucket, src_key, options) -> ..."
        ]

      func = find!(:copy_object, dest_bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(dest_key)
        2 -> func.(dest_key, src_bucket)
        3 -> func.(dest_key, src_bucket, src_key)
        4 -> func.(dest_key, src_bucket, src_key, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `presign/4` in the
    context of the calling process.
    """
    def presign_response(bucket, http_method, key, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (http_method) -> ...",
          "fn (http_method, key) -> ...",
          "fn (http_method, key, options) -> ..."
        ]

      func = find!(:presign, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(http_method)
        2 -> func.(http_method, key)
        3 -> func.(http_method, key, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `presign_post/3` in the
    context of the calling process.
    """
    def presign_post_response(bucket, key, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (key) -> ...",
          "fn (key, options) -> ..."
        ]

      func = find!(:presign_post, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(key)
        2 -> func.(key, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `presign_part/5` in the
    context of the calling process.
    """
    def presign_part_response(bucket, object, upload_id, part_number, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (object) -> ...",
          "fn (object, upload_id) -> ...",
          "fn (object, upload_id, part_number) -> ...",
          "fn (object, upload_id, part_number, options) -> ..."
        ]

      func = find!(:presign_part, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(object)
        2 -> func.(object, upload_id)
        3 -> func.(object, upload_id, part_number)
        4 -> func.(object, upload_id, part_number, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `create_multipart_upload/3` in the
    context of the calling process.
    """
    def create_multipart_upload_response(bucket, key, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (key) -> ...",
          "fn (key, options) -> ..."
        ]

      func = find!(:create_multipart_upload, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(key)
        2 -> func.(key, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `abort_multipart_upload/4` in the
    context of the calling process.
    """
    def abort_multipart_upload_response(bucket, key, upload_id, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (key) -> ...",
          "fn (key, upload_id) -> ...",
          "fn (key, upload_id, options) -> ..."
        ]

      func = find!(:abort_multipart_upload, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(key)
        2 -> func.(key, upload_id)
        3 -> func.(key, upload_id, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `upload_part/6` in the
    context of the calling process.
    """
    def upload_part_response(bucket, key, upload_id, part_number, body, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (key) -> ...",
          "fn (key, upload_id) -> ...",
          "fn (key, upload_id, part_number) -> ...",
          "fn (key, upload_id, part_number, body) -> ...",
          "fn (key, upload_id, part_number, body, options) -> ..."
        ]

      func = find!(:upload_part, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(key)
        2 -> func.(key, upload_id)
        3 -> func.(key, upload_id, part_number)
        4 -> func.(key, upload_id, part_number, body)
        5 -> func.(key, upload_id, part_number, body, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `list_parts/5` in the
    context of the calling process.
    """
    def list_parts_response(bucket, key, upload_id, part_number_marker, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (key) -> ...",
          "fn (key, upload_id) -> ...",
          "fn (key, upload_id, part_number_marker) -> ...",
          "fn (key, upload_id, part_number_marker, options) -> ..."
        ]

      func = find!(:list_parts, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(key)
        2 -> func.(key, upload_id)
        3 -> func.(key, upload_id, part_number_marker)
        4 -> func.(key, upload_id, part_number_marker, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `copy_part/8` in the
    context of the calling process.
    """
    # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
    def copy_part_response(
          dest_bucket,
          dest_key,
          src_bucket,
          src_key,
          upload_id,
          part_number,
          src_range,
          opts
        ) do
      doc_examples =
        [
          "fn -> ...",
          "fn (dest_key) -> ...",
          "fn (dest_key, src_bucket) -> ...",
          "fn (dest_key, src_bucket, src_key) -> ...",
          "fn (dest_key, src_bucket, src_key, upload_id) -> ...",
          "fn (dest_key, src_bucket, src_key, upload_id, part_number) -> ...",
          "fn (dest_key, src_bucket, src_key, upload_id, part_number, src_range) -> ...",
          "fn (dest_key, src_bucket, src_key, upload_id, part_number, src_range, options) -> ..."
        ]

      func = find!(:copy_part, dest_bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(dest_key)
        2 -> func.(dest_key, src_bucket)
        3 -> func.(dest_key, src_bucket, src_key)
        4 -> func.(dest_key, src_bucket, src_key, upload_id)
        5 -> func.(dest_key, src_bucket, src_key, upload_id, part_number)
        6 -> func.(dest_key, src_bucket, src_key, upload_id, part_number, src_range)
        7 -> func.(dest_key, src_bucket, src_key, upload_id, part_number, src_range, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `copy_parts/7` in the
    context of the calling process.
    """
    def copy_parts_response(
          dest_bucket,
          dest_key,
          src_bucket,
          src_key,
          upload_id,
          content_length,
          opts
        ) do
      doc_examples =
        [
          "fn -> ...",
          "fn (dest_key) -> ...",
          "fn (dest_key, src_bucket) -> ...",
          "fn (dest_key, src_bucket, src_key) -> ...",
          "fn (dest_key, src_bucket, src_key, upload_id) -> ...",
          "fn (dest_key, src_bucket, src_key, upload_id, content_length) -> ...",
          "fn (dest_key, src_bucket, src_key, upload_id, content_length, options) -> ..."
        ]

      func = find!(:copy_parts, dest_bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(dest_key)
        2 -> func.(dest_key, src_bucket)
        3 -> func.(dest_key, src_bucket, src_key)
        4 -> func.(dest_key, src_bucket, src_key, upload_id)
        5 -> func.(dest_key, src_bucket, src_key, upload_id, content_length)
        6 -> func.(dest_key, src_bucket, src_key, upload_id, content_length, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `complete_multipart_upload/5` in the
    context of the calling process.
    """
    def complete_multipart_upload_response(bucket, key, upload_id, parts, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (key) -> ...",
          "fn (key, upload_id) -> ...",
          "fn (key, upload_id, parts) -> ...",
          "fn (key, upload_id, parts, options) -> ..."
        ]

      func = find!(:complete_multipart_upload, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(key)
        2 -> func.(key, upload_id)
        3 -> func.(key, upload_id, parts)
        4 -> func.(key, upload_id, parts, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # Response registration functions

    def set_list_buckets_responses(funcs) do
      set_responses(:list_buckets, Enum.map(funcs, fn f -> {"*", f} end))
    end

    def set_create_bucket_responses(tuples) do
      set_responses(:create_bucket, tuples)
    end

    def set_delete_bucket_responses(tuples) do
      set_responses(:delete_bucket, tuples)
    end

    def set_put_object_responses(tuples) do
      set_responses(:put_object, tuples)
    end

    def set_head_object_responses(tuples) do
      set_responses(:head_object, tuples)
    end

    def set_delete_object_responses(tuples) do
      set_responses(:delete_object, tuples)
    end

    def set_get_object_responses(tuples) do
      set_responses(:get_object, tuples)
    end

    def set_list_objects_responses(tuples) do
      set_responses(:list_objects, tuples)
    end

    def set_copy_object_responses(tuples) do
      set_responses(:copy_object, tuples)
    end

    def set_presign_responses(tuples) do
      set_responses(:presign, tuples)
    end

    def set_presign_post_responses(tuples) do
      set_responses(:presign_post, tuples)
    end

    def set_presign_part_responses(tuples) do
      set_responses(:presign_part, tuples)
    end

    def set_create_multipart_upload_responses(tuples) do
      set_responses(:create_multipart_upload, tuples)
    end

    def set_abort_multipart_upload_responses(tuples) do
      set_responses(:abort_multipart_upload, tuples)
    end

    def set_upload_part_responses(tuples) do
      set_responses(:upload_part, tuples)
    end

    def set_list_parts_responses(tuples) do
      set_responses(:list_parts, tuples)
    end

    def set_copy_part_responses(tuples) do
      set_responses(:copy_part, tuples)
    end

    def set_copy_parts_responses(tuples) do
      set_responses(:copy_parts, tuples)
    end

    def set_complete_multipart_upload_responses(tuples) do
      set_responses(:complete_multipart_upload, tuples)
    end

    # S3 EventBridge notification — response retrieval

    def enable_event_bridge_response(bucket, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:enable_event_bridge, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def disable_event_bridge_response(bucket, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:disable_event_bridge, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    def get_notification_configuration_response(bucket, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:get_notification_configuration, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `head_bucket/2` in the
    context of the calling process.
    """
    def head_bucket_response(bucket, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:head_bucket, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `put_public_access_block/2`
    in the context of the calling process.
    """
    def put_public_access_block_response(bucket, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:put_public_access_block, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for `put_bucket_encryption/2`
    in the context of the calling process.
    """
    def put_bucket_encryption_response(bucket, opts) do
      doc_examples = ["fn -> ...", "fn (opts) -> ..."]
      func = find!(:put_bucket_encryption, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc """
    Returns the registered response function for
    `put_bucket_lifecycle_configuration/3` in the context of the calling
    process.
    """
    def put_bucket_lifecycle_configuration_response(bucket, rules, opts) do
      doc_examples =
        [
          "fn -> ...",
          "fn (rules) -> ...",
          "fn (rules, opts) -> ..."
        ]

      func = find!(:put_bucket_lifecycle_configuration, bucket, doc_examples)

      case :erlang.fun_info(func)[:arity] do
        0 -> func.()
        1 -> func.(rules)
        2 -> func.(rules, opts)
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    # S3 EventBridge notification — response registration

    def set_enable_event_bridge_responses(tuples) do
      set_responses(:enable_event_bridge, tuples)
    end

    def set_disable_event_bridge_responses(tuples) do
      set_responses(:disable_event_bridge, tuples)
    end

    def set_get_notification_configuration_responses(tuples) do
      set_responses(:get_notification_configuration, tuples)
    end

    def set_head_bucket_responses(tuples) do
      set_responses(:head_bucket, tuples)
    end

    def set_put_public_access_block_responses(tuples) do
      set_responses(:put_public_access_block, tuples)
    end

    def set_put_bucket_encryption_responses(tuples) do
      set_responses(:put_bucket_encryption, tuples)
    end

    def set_put_bucket_lifecycle_configuration_responses(tuples) do
      set_responses(:put_bucket_lifecycle_configuration, tuples)
    end

    # Sandbox control

    @doc """
    Disables the sandbox for the calling process.
    """
    @spec disable_s3_sandbox(map) :: :ok
    def disable_s3_sandbox(_context) do
      with {:error, :registry_not_started} <-
             SandboxRegistry.register(@registry, @disabled, %{}, @keys) do
        raise_not_started!()
      end
    end

    @doc """
    Returns true if the sandbox is disabled for the calling process.
    """
    @spec sandbox_disabled? :: boolean
    def sandbox_disabled? do
      case SandboxRegistry.lookup(@registry, @disabled) do
        {:ok, _} -> true
        {:error, :registry_not_started} -> raise_not_started!()
        {:error, :pid_not_registered} -> false
      end
    end

    # Private helpers

    defp set_responses(key, tuples) do
      tuples
      |> Map.new(fn {bucket, func} -> {{key, bucket}, func} end)
      |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
      |> then(fn
        :ok -> :ok
        {:error, :registry_not_started} -> raise_not_started!()
      end)

      Process.sleep(@sleep)
    end

    @doc """
    Returns the registered response function for a given `action`
    and `bucket` pair, or raises an error message if the registry
    or handlers are not set up.

    `find!/3` looks up the current process (or its ancestor chain)
    in the sandbox registry and resolves the response function to
    call for the given `action` and `bucket`.

    ## Matching rules

    `find!/3` checks registered responses in this order:

      1. **Exact match:** when the bucket string matches exactly.

      2. **Regex match:** when the bucket string matches a
        registered regular expression.

    ## Returns

      * The **response function** to be invoked by the caller.

    ## Raises

      * `RuntimeError` with guidance if **no functions have been
        registered** for the calling PID.

      * `RuntimeError` with setup instructions if the **registry
        is not started**.

      * `RuntimeError` with a detailed diff if a **function is not
        found** for the given `action/bucket`.

      * `RuntimeError` if the **registered value has an unexpected
        format** (e.g., not a function).

    If nothing is registered for the calling PID, `find!/3` raises
    with a message that shows the available keys and an example of
    how to register responses for the given `action` and `bucket`.
    """
    def find!(action, bucket, doc_examples) do
      case SandboxRegistry.lookup(@registry, @state) do
        {:ok, state} ->
          find_response!(state, action, bucket, doc_examples)

        {:error, :pid_not_registered} ->
          raise """
          No functions have been registered for #{inspect(self())}.

          Action: #{inspect(action)}
          Bucket: #{inspect(bucket)}

          Add one of the following patterns to your test setup:

          #{format_example(action, bucket, doc_examples)}

          Replace `_response` with the value you want the sandbox to return.
          This determines how #{inspect(__MODULE__)} responds when
          `#{inspect(action)}` is called on bucket "#{bucket}".
          """

        {:error, :registry_not_started} ->
          raise """
          Registry not started for #{inspect(__MODULE__)}.

          Add the following line to your `test_helper.exs` to ensure the
          registry is started for this application:

              #{inspect(__MODULE__)}.start_link()
          """
      end
    end

    defp find_response!(state, action, bucket, doc_examples) do
      sandbox_key = {action, bucket}

      with state when is_map(state) <- Map.get(state, sandbox_key, state),
           regexes <-
             Enum.filter(state, fn {{_registered_action, registered_pattern}, _func} ->
               regex?(registered_pattern)
             end),
           {_action_pattern, func} when is_function(func) <-
             Enum.find(regexes, state, fn {{registered_action, regex}, _func} ->
               Regex.match?(regex, bucket) and registered_action === action
             end) do
        func
      else
        func when is_function(func) ->
          func

        functions when is_map(functions) ->
          functions_text =
            Enum.map_join(functions, "\n", fn {key, val} ->
              " #{inspect(key)} => #{inspect(val)}"
            end)

          example =
            action
            |> format_example(bucket, doc_examples)
            |> indent("  ")

          raise """
          Function not found.

            action: #{inspect(action)}
            bucket: #{inspect(bucket)}
            pid: #{inspect(self())}

          Found:

          #{functions_text}

          ---

          You need to register mock responses for `#{inspect(action)}` requests
          so the sandbox knows how to respond during tests.

          Add the following to your `test_helper.exs` or inside the test's
          `setup` block:

          #{example}
          """

        other ->
          raise """
          Unrecognized input for #{inspect(sandbox_key)} in #{inspect(self())}.

          Response does not match the expected format for #{inspect(__MODULE__)}.

          Found value:

          #{inspect(other)}

          To fix this, update your test setup to include one of the following
          response patterns:

          #{format_example(action, bucket, doc_examples)}

          Replace `_response` with the value you want the sandbox to return.
          This determines how #{inspect(__MODULE__)} responds when
          `#{inspect(action)}` is called on bucket "#{bucket}".
          """
      end
    end

    defp regex?(%Regex{}), do: true
    defp regex?(_), do: false

    defp indent(text, prefix) do
      text
      |> String.split("\n", trim: false)
      |> Enum.map_join("\n", &"#{prefix}#{&1}")
    end

    defp format_example(action, _bucket, doc_examples) do
      """
      alias #{inspect(__MODULE__)}

      setup do
        #{inspect(__MODULE__)}.set_#{action}_responses([
          #{Enum.map_join(doc_examples, "\n    # or\n", &("    " <> &1))}
          # or
          {~r|pattern|, fn -> _response end}
        ])
      end
      """
    end

    defp raise_unsupported_arity(func, doc_examples) do
      raise """
      This function's signature is not supported: #{inspect(func)}

      Please provide a function with one of the following arities (0-#{length(doc_examples) - 1}):

      #{Enum.map_join(doc_examples, "\n", &("    " <> &1))}
      """
    end

    defp raise_not_started! do
      raise """
      Registry not started for #{inspect(__MODULE__)}.

      To fix this, add the following line to your `test_helper.exs`:

          #{inspect(__MODULE__)}.start_link()

      This ensures the registry is running for your tests.
      """
    end
  end
end
