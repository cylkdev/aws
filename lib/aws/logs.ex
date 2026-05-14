defmodule AWS.Logs do
  @moduledoc """
  `AWS.Logs` provides an API for Amazon CloudWatch Logs.

  This API calls the AWS CloudWatch Logs JSON 1.1 API directly over HTTP using
  `Finch` as the HTTP client (via `AWS.HTTP`), Erlang's built-in `:json` for
  encoding/decoding (OTP 27+ required), and a SigV4 signer (`AWS.Signer`). It
  provides consistent error handling, response deserialization, and sandbox
  support.

  CloudWatch Logs uses camelCase (lowercase first letter) keys on the wire.

  ## Shared Options

  Credentials and region are flat top-level opts on every call (ex_aws shape).
  Each accepts a literal, a source tuple, or a list of sources (first
  non-nil wins):

    - `:access_key_id`, `:secret_access_key`, `:security_token`, `:region` -
      Sources: literal binary, `{:system, "ENV"}`, `:instance_role`,
      `:ecs_task_role`, `{:awscli, profile}` / `{:awscli, profile, ttl}`,
      a module, or a list of any of these. Map-returning sources merge
      into the outer config. `{:awscli, _}` is not in the default chain —
      callers opt in explicitly.

  The following options are also available:

    - `:logs` - A keyword list of CloudWatch Logs endpoint overrides.
      Supported keys: `:scheme`, `:host`, `:port`. Credentials are not
      read from this sub-list; use the top-level keys above.

    - `:sandbox` - A keyword list to override sandbox configuration.
        - `:enabled` - Whether sandbox mode is enabled.
        - `:scheme` - The sandbox scheme.
        - `:host` - The sandbox host.
        - `:port` - The sandbox port.

  ## Sandbox

  Set `sandbox: [enabled: true]` to activate sandbox mode.

  ### Setup

  Add the following to your `test_helper.exs`:

      AWS.Logs.Sandbox.start_link()

  ### Usage

      setup do
        AWS.Logs.Sandbox.set_create_log_group_responses([
          {"my-group", fn -> {:ok, %{}} end}
        ])
      end

      test "creates a log group" do
        assert {:ok, %{}} =
                 AWS.Logs.create_log_group("my-group",
                   sandbox: [enabled: true]
                 )
      end
  """

  alias AWS.{Client, Config}
  alias AWS.Logs.Operation
  alias ExUtils.Serializer

  @service "logs"
  @content_type "application/x-amz-json-1.1"
  @target_prefix "Logs_20140328"

  @override_keys [:headers, :body, :http, :url]

  # Log Groups

  @doc """
  Creates a log group.

  ## Options

    * `:kms_key_id` - KMS key ARN for log group encryption.
    * `:tags` - Map of tags to attach.
  """
  @spec create_log_group(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_log_group(name, opts \\ []) do
    if sandbox?(opts) do
      sandbox_create_log_group_response(name, opts)
    else
      do_create_log_group(name, opts)
    end
  end

  defp do_create_log_group(name, opts) do
    data =
      %{"logGroupName" => name}
      |> maybe_put("kmsKeyId", opts[:kms_key_id])
      |> maybe_put("tags", opts[:tags])

    perform("CreateLogGroup", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Deletes a log group.
  """
  @spec delete_log_group(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def delete_log_group(name, opts \\ []) do
    if sandbox?(opts) do
      sandbox_delete_log_group_response(name, opts)
    else
      do_delete_log_group(name, opts)
    end
  end

  defp do_delete_log_group(name, opts) do
    perform("DeleteLogGroup", %{"logGroupName" => name}, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Lists log groups, optionally filtered by name prefix.

  ## Options

    * `:log_group_name_prefix` - Filter by prefix.
    * `:limit` - Max results per page.
    * `:next_token` - Pagination token.
  """
  @spec describe_log_groups(opts :: keyword()) ::
          {:ok, %{log_groups: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def describe_log_groups(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_log_groups_response(opts)
    else
      do_describe_log_groups(opts)
    end
  end

  defp do_describe_log_groups(opts) do
    data =
      %{}
      |> maybe_put("logGroupNamePrefix", opts[:log_group_name_prefix])
      |> maybe_put("limit", opts[:limit])
      |> maybe_put("nextToken", opts[:next_token])

    perform("DescribeLogGroups", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Sets retention for a log group, in days (e.g. 1, 7, 30, 90, 365).
  """
  @spec put_retention_policy(name :: String.t(), days :: pos_integer(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def put_retention_policy(name, days, opts \\ []) do
    if sandbox?(opts) do
      sandbox_put_retention_policy_response(name, days, opts)
    else
      do_put_retention_policy(name, days, opts)
    end
  end

  defp do_put_retention_policy(name, days, opts) do
    data = %{"logGroupName" => name, "retentionInDays" => days}

    perform("PutRetentionPolicy", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Removes the retention policy from a log group (reverts to never expire).
  """
  @spec delete_retention_policy(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def delete_retention_policy(name, opts \\ []) do
    if sandbox?(opts) do
      sandbox_delete_retention_policy_response(name, opts)
    else
      do_delete_retention_policy(name, opts)
    end
  end

  defp do_delete_retention_policy(name, opts) do
    perform("DeleteRetentionPolicy", %{"logGroupName" => name}, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  # Log Streams

  @doc """
  Creates a log stream inside a log group.
  """
  @spec create_log_stream(group :: String.t(), stream :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_log_stream(group, stream, opts \\ []) do
    if sandbox?(opts) do
      sandbox_create_log_stream_response(group, stream, opts)
    else
      do_create_log_stream(group, stream, opts)
    end
  end

  defp do_create_log_stream(group, stream, opts) do
    data = %{"logGroupName" => group, "logStreamName" => stream}

    perform("CreateLogStream", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Deletes a log stream.
  """
  @spec delete_log_stream(group :: String.t(), stream :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def delete_log_stream(group, stream, opts \\ []) do
    if sandbox?(opts) do
      sandbox_delete_log_stream_response(group, stream, opts)
    else
      do_delete_log_stream(group, stream, opts)
    end
  end

  defp do_delete_log_stream(group, stream, opts) do
    data = %{"logGroupName" => group, "logStreamName" => stream}

    perform("DeleteLogStream", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Lists log streams for a log group.

  ## Options

    * `:log_stream_name_prefix` - Filter by prefix.
    * `:order_by` - `"LogStreamName"` or `"LastEventTime"`.
    * `:descending` - Boolean.
    * `:limit` - Max results per page.
    * `:next_token` - Pagination token.
  """
  @spec describe_log_streams(group :: String.t(), opts :: keyword()) ::
          {:ok, %{log_streams: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def describe_log_streams(group, opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_log_streams_response(group, opts)
    else
      do_describe_log_streams(group, opts)
    end
  end

  defp do_describe_log_streams(group, opts) do
    data =
      %{"logGroupName" => group}
      |> maybe_put("logStreamNamePrefix", opts[:log_stream_name_prefix])
      |> maybe_put("orderBy", opts[:order_by])
      |> maybe_put("descending", opts[:descending])
      |> maybe_put("limit", opts[:limit])
      |> maybe_put("nextToken", opts[:next_token])

    perform("DescribeLogStreams", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  # Log Events

  @doc """
  Writes log events to a log stream.

  ## Arguments

    * `group` - Log group name.
    * `stream` - Log stream name.
    * `events` - List of maps with `:timestamp` (ms since epoch) and `:message`.
    * `opts` - Shared options.
  """
  @spec put_log_events(
          group :: String.t(),
          stream :: String.t(),
          events :: list(map()),
          opts :: keyword()
        ) ::
          {:ok, map()} | {:error, term()}
  def put_log_events(group, stream, events, opts \\ []) do
    if sandbox?(opts) do
      sandbox_put_log_events_response(group, stream, events, opts)
    else
      do_put_log_events(group, stream, events, opts)
    end
  end

  defp do_put_log_events(group, stream, events, opts) do
    data = %{
      "logGroupName" => group,
      "logStreamName" => stream,
      "logEvents" => Enum.map(events, &camelize_keys/1)
    }

    perform("PutLogEvents", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Reads log events from a log stream.

  ## Options

    * `:start_time` / `:end_time` - Epoch milliseconds.
    * `:start_from_head` - Boolean; read oldest first.
    * `:limit` - Max events per page.
    * `:next_token` - Pagination token.
  """
  @spec get_log_events(group :: String.t(), stream :: String.t(), opts :: keyword()) ::
          {:ok, %{events: list(map()), next_forward_token: String.t() | nil}} | {:error, term()}
  def get_log_events(group, stream, opts \\ []) do
    if sandbox?(opts) do
      sandbox_get_log_events_response(group, stream, opts)
    else
      do_get_log_events(group, stream, opts)
    end
  end

  defp do_get_log_events(group, stream, opts) do
    data =
      %{"logGroupName" => group, "logStreamName" => stream}
      |> maybe_put("startTime", opts[:start_time])
      |> maybe_put("endTime", opts[:end_time])
      |> maybe_put("startFromHead", opts[:start_from_head])
      |> maybe_put("limit", opts[:limit])
      |> maybe_put("nextToken", opts[:next_token])

    perform("GetLogEvents", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Searches log events across one or more streams in a group.

  ## Options

    * `:filter_pattern` - CloudWatch Logs filter syntax.
    * `:log_stream_names` - List of stream names to search.
    * `:start_time` / `:end_time` - Epoch milliseconds.
    * `:limit` - Max events per page.
    * `:next_token` - Pagination token.
  """
  @spec filter_log_events(group :: String.t(), opts :: keyword()) ::
          {:ok, %{events: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def filter_log_events(group, opts \\ []) do
    if sandbox?(opts) do
      sandbox_filter_log_events_response(group, opts)
    else
      do_filter_log_events(group, opts)
    end
  end

  defp do_filter_log_events(group, opts) do
    data =
      %{"logGroupName" => group}
      |> maybe_put("filterPattern", opts[:filter_pattern])
      |> maybe_put("logStreamNames", opts[:log_stream_names])
      |> maybe_put("startTime", opts[:start_time])
      |> maybe_put("endTime", opts[:end_time])
      |> maybe_put("limit", opts[:limit])
      |> maybe_put("nextToken", opts[:next_token])

    perform("FilterLogEvents", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  # Insights Queries

  @doc """
  Starts a CloudWatch Logs Insights query.

  ## Arguments

    * `group` - Log group to query.
    * `start_time` / `end_time` - Epoch seconds.
    * `query` - Logs Insights query string.
    * `opts` - May include `:limit`.
  """
  @spec start_query(
          group :: String.t(),
          start_time :: non_neg_integer(),
          end_time :: non_neg_integer(),
          query :: String.t(),
          opts :: keyword()
        ) ::
          {:ok, %{query_id: String.t()}} | {:error, term()}
  def start_query(group, start_time, end_time, query, opts \\ []) do
    if sandbox?(opts) do
      sandbox_start_query_response(group, start_time, end_time, query, opts)
    else
      do_start_query(group, start_time, end_time, query, opts)
    end
  end

  defp do_start_query(group, start_time, end_time, query, opts) do
    base = %{
      "logGroupName" => group,
      "startTime" => start_time,
      "endTime" => end_time,
      "queryString" => query
    }

    data = maybe_put(base, "limit", opts[:limit])

    perform("StartQuery", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Fetches results for an Insights query started by `start_query/5`.
  """
  @spec get_query_results(query_id :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_query_results(query_id, opts \\ []) do
    if sandbox?(opts) do
      sandbox_get_query_results_response(query_id, opts)
    else
      do_get_query_results(query_id, opts)
    end
  end

  defp do_get_query_results(query_id, opts) do
    perform("GetQueryResults", %{"queryId" => query_id}, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Stops an in-flight Insights query.
  """
  @spec stop_query(query_id :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def stop_query(query_id, opts \\ []) do
    if sandbox?(opts) do
      sandbox_stop_query_response(query_id, opts)
    else
      do_stop_query(query_id, opts)
    end
  end

  defp do_stop_query(query_id, opts) do
    perform("StopQuery", %{"queryId" => query_id}, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @doc false
  def build_operation(action, data, opts) do
    with {:ok, config} <- Client.resolve_config(:logs, opts, &"logs.#{&1}.amazonaws.com") do
      op = %Operation{
        method: :post,
        url: Client.simple_url(config),
        headers: [
          {"content-type", @content_type},
          {"x-amz-target", "#{@target_prefix}.#{action}"}
        ],
        body: encode_body(data),
        service: @service,
        region: config.region,
        access_key_id: config.access_key_id,
        secret_access_key: config.secret_access_key,
        security_token: config.security_token,
        http: Keyword.get(opts, :http, [])
      }

      {:ok, apply_overrides(op, opts[:logs] || [])}
    end
  end

  defp perform(action, data, opts) do
    with {:ok, op} <- build_operation(action, data, opts) do
      op
      |> Client.execute()
      |> decode_response()
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

  defp encode_body(data) when map_size(data) === 0, do: "{}"
  defp encode_body(data), do: data |> :json.encode() |> IO.iodata_to_binary()

  defp decode_response({:ok, %{body: body}}), do: {:ok, decode_body(body)}

  defp decode_response({:error, {:http_error, status, body}}),
    do: {:error, {:http_error, status, decode_body(body)}}

  defp decode_response({:error, _reason} = err), do: err

  defp decode_body(""), do: %{}

  defp decode_body(binary) when is_binary(binary) do
    :json.decode(binary)
  rescue
    _ -> binary
  end

  # AWS owns the response-body namespace and adds new fields over time.
  # `Serializer.deserialize/2`'s default is `to_existing_atom: true, strict: true`,
  # which crashes on any field whose snake-cased atom hasn't been referenced
  # elsewhere in the project. Bodies must round-trip without crashing, so
  # atom-safety is relaxed here by default. Callers can still override any of
  # these options by passing their own `opts` -- caller-supplied keys win the merge.
  @deserialize_defaults [to_existing_atom: false, strict: false]

  defp deserialize_opts(opts), do: Keyword.merge(@deserialize_defaults, opts)

  defp deserialize_response({:ok, response}, _opts, func) do
    case func.(response) do
      {:error, _} = error -> error
      {:ok, _} = ok -> ok
      result -> {:ok, result}
    end
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, _opts, _func)
       when status_code in 400..499 do
    {:error, ErrorMessage.not_found("resource not found.", %{response: response})}
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, _opts, _func)
       when status_code >= 500 do
    {:error,
     ErrorMessage.service_unavailable("service temporarily unavailable", %{response: response})}
  end

  defp deserialize_response({:error, reason}, _opts, _func) do
    {:error, ErrorMessage.internal_server_error("internal server error", %{reason: reason})}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, false), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # CloudWatch Logs uses camelCase (lowercase first letter) keys on the wire.
  defp camelize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {camelize(k), camelize_keys(v)} end)
  end

  defp camelize_keys(list) when is_list(list), do: Enum.map(list, &camelize_keys/1)
  defp camelize_keys(other), do: other

  defp camelize(key) when is_atom(key), do: key |> Atom.to_string() |> Recase.to_camel()
  defp camelize(key) when is_binary(key), do: Recase.to_camel(key)

  # ---------------------------------------------------------------------------
  # Sandbox delegation
  # ---------------------------------------------------------------------------

  defp sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    cfg = Config.sandbox()
    enabled = Keyword.get(sandbox_opts, :enabled, cfg[:enabled])

    enabled and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    @doc false
    defdelegate sandbox_disabled?, to: AWS.Logs.Sandbox

    # Log Groups
    @doc false
    defdelegate sandbox_create_log_group_response(name, opts),
      to: AWS.Logs.Sandbox,
      as: :create_log_group_response

    @doc false
    defdelegate sandbox_delete_log_group_response(name, opts),
      to: AWS.Logs.Sandbox,
      as: :delete_log_group_response

    @doc false
    defdelegate sandbox_describe_log_groups_response(opts),
      to: AWS.Logs.Sandbox,
      as: :describe_log_groups_response

    @doc false
    defdelegate sandbox_put_retention_policy_response(name, days, opts),
      to: AWS.Logs.Sandbox,
      as: :put_retention_policy_response

    @doc false
    defdelegate sandbox_delete_retention_policy_response(name, opts),
      to: AWS.Logs.Sandbox,
      as: :delete_retention_policy_response

    # Log Streams
    @doc false
    defdelegate sandbox_create_log_stream_response(group, stream, opts),
      to: AWS.Logs.Sandbox,
      as: :create_log_stream_response

    @doc false
    defdelegate sandbox_delete_log_stream_response(group, stream, opts),
      to: AWS.Logs.Sandbox,
      as: :delete_log_stream_response

    @doc false
    defdelegate sandbox_describe_log_streams_response(group, opts),
      to: AWS.Logs.Sandbox,
      as: :describe_log_streams_response

    # Log Events
    @doc false
    defdelegate sandbox_put_log_events_response(group, stream, events, opts),
      to: AWS.Logs.Sandbox,
      as: :put_log_events_response

    @doc false
    defdelegate sandbox_get_log_events_response(group, stream, opts),
      to: AWS.Logs.Sandbox,
      as: :get_log_events_response

    @doc false
    defdelegate sandbox_filter_log_events_response(group, opts),
      to: AWS.Logs.Sandbox,
      as: :filter_log_events_response

    # Insights Queries
    @doc false
    defdelegate sandbox_start_query_response(group, start_time, end_time, query, opts),
      to: AWS.Logs.Sandbox,
      as: :start_query_response

    @doc false
    defdelegate sandbox_get_query_results_response(query_id, opts),
      to: AWS.Logs.Sandbox,
      as: :get_query_results_response

    @doc false
    defdelegate sandbox_stop_query_response(query_id, opts),
      to: AWS.Logs.Sandbox,
      as: :stop_query_response
  else
    defp sandbox_disabled?, do: true

    defp sandbox_create_log_group_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_log_group_response(_, _), do: raise("sandbox not available")
    defp sandbox_describe_log_groups_response(_), do: raise("sandbox not available")
    defp sandbox_put_retention_policy_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_delete_retention_policy_response(_, _), do: raise("sandbox not available")
    defp sandbox_create_log_stream_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_delete_log_stream_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_describe_log_streams_response(_, _), do: raise("sandbox not available")
    defp sandbox_put_log_events_response(_, _, _, _), do: raise("sandbox not available")
    defp sandbox_get_log_events_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_filter_log_events_response(_, _), do: raise("sandbox not available")
    defp sandbox_start_query_response(_, _, _, _, _), do: raise("sandbox not available")
    defp sandbox_get_query_results_response(_, _), do: raise("sandbox not available")
    defp sandbox_stop_query_response(_, _), do: raise("sandbox not available")
  end
end
