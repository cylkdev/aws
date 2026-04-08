defmodule AWS.EventBridge do
  @moduledoc """
  `AWS.EventBridge` provides an API for Amazon EventBridge.

  This API wraps EventBridge operations using `ExAws.EventBridge` (from `ex_aws_eventbridge`)
  for event bus operations, and `ExAws.Operation.JSON` directly for rules, targets,
  connections, and API destinations not covered by that package. It provides consistent
  error handling, response deserialization, and sandbox support.

  ## Shared Options

  The following options are available for most functions in this API:

    - `:region` - The AWS region. Defaults to `AWS.Config.region()`.

    - `:events` - A keyword list of options used to configure the ExAws events service.
      See `ExAws.Config.new/2` for available options.

    - `:sandbox` - A keyword list to override sandbox configuration.
        - `:enabled` - Whether sandbox mode is enabled.
        - `:mode` - `:local` or `:inline`.
        - `:scheme` - The sandbox scheme.
        - `:host` - The sandbox host.
        - `:port` - The sandbox port.

  ## Sandbox

  Set `sandbox: [enabled: true, mode: :inline]` to activate inline sandbox mode.

  ### Setup

  Add the following to your `test_helper.exs`:

      AWS.EventBridge.Sandbox.start_link()

  ### Usage

      setup do
        AWS.EventBridge.Sandbox.set_put_rule_responses([
          {"my-rule", fn -> {:ok, %{rule_arn: "arn:aws:events:us-west-1:123:rule/my-rule"}} end}
        ])
      end

      test "creates a rule" do
        assert {:ok, %{rule_arn: _}} =
                 AWS.EventBridge.put_rule("my-rule",
                   event_pattern: %{"source" => ["aws.s3"]},
                   sandbox: [enabled: true, mode: :inline]
                 )
      end
  """

  alias AWS.{Config, Error, Serializer}

  # Rule management

  @doc """
  Creates or updates an EventBridge rule.

  ## Arguments

    * `name` - The rule name (1-64 chars).
    * `opts` - Options including `:event_pattern`, `:description`, `:state`,
      `:role_arn`, `:event_bus_name`, plus shared options.
  """
  @spec put_rule(name :: String.t(), opts :: keyword()) ::
          {:ok, %{rule_arn: String.t()}} | {:error, term()}
  def put_rule(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_rule_response(name, opts)
    else
      do_put_rule(name, opts)
    end
  end

  defp do_put_rule(name, opts) do
    data =
      %{"Name" => name}
      |> maybe_put("EventPattern", opts[:event_pattern], &Jason.encode!/1)
      |> maybe_put("ScheduleExpression", opts[:schedule_expression])
      |> maybe_put("Description", opts[:description])
      |> maybe_put("State", opts[:state])
      |> maybe_put("RoleArn", opts[:role_arn])
      |> maybe_put("EventBusName", opts[:event_bus_name])

    build_operation("PutRule", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Returns details about an EventBridge rule.
  """
  @spec describe_rule(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def describe_rule(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_rule_response(name, opts)
    else
      do_describe_rule(name, opts)
    end
  end

  defp do_describe_rule(name, opts) do
    data =
      %{"Name" => name}
      |> maybe_put("EventBusName", opts[:event_bus_name])

    build_operation("DescribeRule", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Lists EventBridge rules, optionally filtered by name prefix.
  """
  @spec list_rules(opts :: keyword()) ::
          {:ok, %{rules: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def list_rules(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_rules_response(opts)
    else
      do_list_rules(opts)
    end
  end

  defp do_list_rules(opts) do
    data =
      %{}
      |> maybe_put("NamePrefix", opts[:name_prefix])
      |> maybe_put("EventBusName", opts[:event_bus_name])
      |> maybe_put("Limit", opts[:limit])
      |> maybe_put("NextToken", opts[:next_token])

    build_operation("ListRules", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Deletes an EventBridge rule. Targets must be removed first.
  """
  @spec delete_rule(name :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_rule(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_rule_response(name, opts)
    else
      do_delete_rule(name, opts)
    end
  end

  defp do_delete_rule(name, opts) do
    data =
      %{"Name" => name}
      |> maybe_put("EventBusName", opts[:event_bus_name])
      |> maybe_put("Force", opts[:force])

    build_operation("DeleteRule", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  # Target management

  @doc """
  Adds targets to an EventBridge rule.

  ## Arguments

    * `rule` - The rule name.
    * `targets` - List of target maps with `:id`, `:arn`, and optional `:role_arn`, `:input`, `:input_path`.
    * `opts` - Options including `:event_bus_name`, plus shared options.
  """
  @spec put_targets(rule :: String.t(), targets :: list(map()), opts :: keyword()) ::
          {:ok, %{failed_entry_count: integer(), failed_entries: list()}} | {:error, term()}
  def put_targets(rule, targets, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_targets_response(rule, targets, opts)
    else
      do_put_targets(rule, targets, opts)
    end
  end

  defp do_put_targets(rule, targets, opts) do
    data =
      %{"Rule" => rule, "Targets" => Enum.map(targets, &camelize_keys/1)}
      |> maybe_put("EventBusName", opts[:event_bus_name])

    build_operation("PutTargets", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Lists targets attached to an EventBridge rule.
  """
  @spec list_targets_by_rule(rule :: String.t(), opts :: keyword()) ::
          {:ok, %{targets: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def list_targets_by_rule(rule, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_targets_by_rule_response(rule, opts)
    else
      do_list_targets_by_rule(rule, opts)
    end
  end

  defp do_list_targets_by_rule(rule, opts) do
    data =
      %{"Rule" => rule}
      |> maybe_put("EventBusName", opts[:event_bus_name])
      |> maybe_put("Limit", opts[:limit])
      |> maybe_put("NextToken", opts[:next_token])

    build_operation("ListTargetsByRule", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Removes targets from an EventBridge rule.
  """
  @spec remove_targets(rule :: String.t(), ids :: list(String.t()), opts :: keyword()) ::
          {:ok, %{failed_entry_count: integer(), failed_entries: list()}} | {:error, term()}
  def remove_targets(rule, ids, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_remove_targets_response(rule, ids, opts)
    else
      do_remove_targets(rule, ids, opts)
    end
  end

  defp do_remove_targets(rule, ids, opts) do
    data =
      %{"Rule" => rule, "Ids" => ids}
      |> maybe_put("EventBusName", opts[:event_bus_name])
      |> maybe_put("Force", opts[:force])

    build_operation("RemoveTargets", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  # Connection management

  @doc """
  Creates a connection that stores authentication credentials for API destinations.

  ## Arguments

    * `name` - Connection name (1-64 chars).
    * `authorization_type` - One of `"API_KEY"`, `"BASIC"`, `"OAUTH_CLIENT_CREDENTIALS"`.
    * `auth_parameters` - Map with PascalCase keys matching the AWS API
      (e.g., `%{"ApiKeyAuthParameters" => %{"ApiKeyName" => "...", "ApiKeyValue" => "..."}}`).
    * `opts` - Options including `:description`, plus shared options.
  """
  @spec create_connection(name :: String.t(), authorization_type :: String.t(), auth_parameters :: map(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_connection(name, authorization_type, auth_parameters, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_connection_response(name, authorization_type, auth_parameters, opts)
    else
      do_create_connection(name, authorization_type, auth_parameters, opts)
    end
  end

  defp do_create_connection(name, authorization_type, auth_parameters, opts) do
    data =
      %{
        "Name" => name,
        "AuthorizationType" => authorization_type,
        "AuthParameters" => auth_parameters
      }
      |> maybe_put("Description", opts[:description])

    build_operation("CreateConnection", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Returns details about a connection.
  """
  @spec describe_connection(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def describe_connection(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_connection_response(name, opts)
    else
      do_describe_connection(name, opts)
    end
  end

  defp do_describe_connection(name, opts) do
    build_operation("DescribeConnection", %{"Name" => name})
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Updates a connection's authorization parameters.

  ## Options

    * `:authorization_type` - New auth type.
    * `:auth_parameters` - New auth parameters (PascalCase map).
    * `:description` - New description.
  """
  @spec update_connection(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def update_connection(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_update_connection_response(name, opts)
    else
      do_update_connection(name, opts)
    end
  end

  defp do_update_connection(name, opts) do
    data =
      %{"Name" => name}
      |> maybe_put("AuthorizationType", opts[:authorization_type])
      |> maybe_put("AuthParameters", opts[:auth_parameters])
      |> maybe_put("Description", opts[:description])

    build_operation("UpdateConnection", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Deletes a connection.
  """
  @spec delete_connection(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def delete_connection(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_connection_response(name, opts)
    else
      do_delete_connection(name, opts)
    end
  end

  defp do_delete_connection(name, opts) do
    build_operation("DeleteConnection", %{"Name" => name})
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Lists connections, optionally filtered by name prefix or state.
  """
  @spec list_connections(opts :: keyword()) ::
          {:ok, %{connections: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def list_connections(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_connections_response(opts)
    else
      do_list_connections(opts)
    end
  end

  defp do_list_connections(opts) do
    data =
      %{}
      |> maybe_put("NamePrefix", opts[:name_prefix])
      |> maybe_put("ConnectionState", opts[:connection_state])
      |> maybe_put("Limit", opts[:limit])
      |> maybe_put("NextToken", opts[:next_token])

    build_operation("ListConnections", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  # API Destination management

  @doc """
  Creates an API destination (HTTP endpoint for event delivery).

  ## Arguments

    * `name` - API destination name (1-64 chars).
    * `connection_arn` - ARN of the connection for authentication.
    * `invocation_endpoint` - Full URL of the HTTP endpoint.
    * `http_method` - HTTP method (`"POST"`, `"GET"`, `"PUT"`, etc.).
    * `opts` - Options including `:description`, `:invocation_rate_limit_per_second`, plus shared options.
  """
  @spec create_api_destination(name :: String.t(), connection_arn :: String.t(), invocation_endpoint :: String.t(), http_method :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_api_destination(name, connection_arn, invocation_endpoint, http_method, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_api_destination_response(name, connection_arn, invocation_endpoint, http_method, opts)
    else
      do_create_api_destination(name, connection_arn, invocation_endpoint, http_method, opts)
    end
  end

  defp do_create_api_destination(name, connection_arn, invocation_endpoint, http_method, opts) do
    data =
      %{
        "Name" => name,
        "ConnectionArn" => connection_arn,
        "InvocationEndpoint" => invocation_endpoint,
        "HttpMethod" => http_method
      }
      |> maybe_put("Description", opts[:description])
      |> maybe_put("InvocationRateLimitPerSecond", opts[:invocation_rate_limit_per_second])

    build_operation("CreateApiDestination", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Returns details about an API destination.
  """
  @spec describe_api_destination(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def describe_api_destination(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_api_destination_response(name, opts)
    else
      do_describe_api_destination(name, opts)
    end
  end

  defp do_describe_api_destination(name, opts) do
    build_operation("DescribeApiDestination", %{"Name" => name})
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Updates an API destination.

  ## Options

    * `:connection_arn` - New connection ARN.
    * `:invocation_endpoint` - New endpoint URL.
    * `:http_method` - New HTTP method.
    * `:description` - New description.
    * `:invocation_rate_limit_per_second` - New rate limit.
  """
  @spec update_api_destination(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def update_api_destination(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_update_api_destination_response(name, opts)
    else
      do_update_api_destination(name, opts)
    end
  end

  defp do_update_api_destination(name, opts) do
    data =
      %{"Name" => name}
      |> maybe_put("ConnectionArn", opts[:connection_arn])
      |> maybe_put("InvocationEndpoint", opts[:invocation_endpoint])
      |> maybe_put("HttpMethod", opts[:http_method])
      |> maybe_put("Description", opts[:description])
      |> maybe_put("InvocationRateLimitPerSecond", opts[:invocation_rate_limit_per_second])

    build_operation("UpdateApiDestination", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Deletes an API destination.
  """
  @spec delete_api_destination(name :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_api_destination(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_api_destination_response(name, opts)
    else
      do_delete_api_destination(name, opts)
    end
  end

  defp do_delete_api_destination(name, opts) do
    build_operation("DeleteApiDestination", %{"Name" => name})
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Lists API destinations, optionally filtered by name prefix or connection.
  """
  @spec list_api_destinations(opts :: keyword()) ::
          {:ok, %{api_destinations: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def list_api_destinations(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_api_destinations_response(opts)
    else
      do_list_api_destinations(opts)
    end
  end

  defp do_list_api_destinations(opts) do
    data =
      %{}
      |> maybe_put("NamePrefix", opts[:name_prefix])
      |> maybe_put("ConnectionArn", opts[:connection_arn])
      |> maybe_put("Limit", opts[:limit])
      |> maybe_put("NextToken", opts[:next_token])

    build_operation("ListApiDestinations", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  # Event Bus management

  @doc """
  Creates a custom event bus.
  """
  @spec create_event_bus(name :: String.t(), opts :: keyword()) ::
          {:ok, %{event_bus_arn: String.t()}} | {:error, term()}
  def create_event_bus(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_create_event_bus_response(name, opts)
    else
      do_create_event_bus(name, opts)
    end
  end

  defp do_create_event_bus(name, opts) do
    ex_opts = compact(event_source_name: opts[:event_source_name])

    ExAws.EventBridge.create_event_bus(name, ex_opts)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Returns details about an event bus.
  """
  @spec describe_event_bus(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def describe_event_bus(name \\ "default", opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_event_bus_response(name, opts)
    else
      do_describe_event_bus(name, opts)
    end
  end

  defp do_describe_event_bus(name, opts) do
    ExAws.EventBridge.describe_event_bus(name)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Deletes a custom event bus. Cannot delete the default bus.
  """
  @spec delete_event_bus(name :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_event_bus(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_event_bus_response(name, opts)
    else
      do_delete_event_bus(name, opts)
    end
  end

  defp do_delete_event_bus(name, opts) do
    ExAws.EventBridge.delete_event_bus(name)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Lists event buses, optionally filtered by name prefix.
  """
  @spec list_event_buses(opts :: keyword()) ::
          {:ok, %{event_buses: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def list_event_buses(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_event_buses_response(opts)
    else
      do_list_event_buses(opts)
    end
  end

  defp do_list_event_buses(opts) do
    ex_opts = compact(name_prefix: opts[:name_prefix], limit: opts[:limit], next_token: opts[:next_token])

    ExAws.EventBridge.list_event_buses(ex_opts)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  # Event publishing

  @doc """
  Publishes events to an event bus.

  ## Arguments

    * `entries` - List of event maps. Each entry should have `:source`, `:detail_type`,
      `:detail` (JSON string), and optionally `:event_bus_name`, `:time`, `:resources`.
    * `opts` - Shared options.
  """
  @spec put_events(entries :: list(map()), opts :: keyword()) ::
          {:ok, %{entries: list(map()), failed_entry_count: integer()}} | {:error, term()}
  def put_events(entries, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_events_response(entries, opts)
    else
      do_put_events(entries, opts)
    end
  end

  defp do_put_events(entries, opts) do
    data = %{"Entries" => Enum.map(entries, &camelize_keys/1)}

    build_operation("PutEvents", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  # Rule control

  @doc """
  Enables a disabled rule.
  """
  @spec enable_rule(name :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def enable_rule(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_enable_rule_response(name, opts)
    else
      do_enable_rule(name, opts)
    end
  end

  defp do_enable_rule(name, opts) do
    data =
      %{"Name" => name}
      |> maybe_put("EventBusName", opts[:event_bus_name])

    build_operation("EnableRule", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  @doc """
  Disables an enabled rule.
  """
  @spec disable_rule(name :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def disable_rule(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_disable_rule_response(name, opts)
    else
      do_disable_rule(name, opts)
    end
  end

  defp do_disable_rule(name, opts) do
    data =
      %{"Name" => name}
      |> maybe_put("EventBusName", opts[:event_bus_name])

    build_operation("DisableRule", data)
    |> perform(opts)
    |> deserialize_response(opts, fn body -> Serializer.deserialize(body) end)
  end

  # Pattern helpers

  @doc """
  Builds an EventBridge event pattern for S3 object creation events.

  ## Examples

      iex> AWS.EventBridge.s3_object_created_pattern("my-bucket")
      %{"source" => ["aws.s3"], "detail-type" => ["Object Created"], "detail" => %{"bucket" => %{"name" => ["my-bucket"]}}}
  """
  @spec s3_object_created_pattern(bucket :: String.t()) :: map()
  def s3_object_created_pattern(bucket) do
    s3_event_pattern("Object Created", bucket)
  end

  @doc """
  Builds an EventBridge event pattern for S3 object deletion events.

  ## Examples

      iex> AWS.EventBridge.s3_object_deleted_pattern("my-bucket")
      %{"source" => ["aws.s3"], "detail-type" => ["Object Deleted"], "detail" => %{"bucket" => %{"name" => ["my-bucket"]}}}
  """
  @spec s3_object_deleted_pattern(bucket :: String.t()) :: map()
  def s3_object_deleted_pattern(bucket) do
    s3_event_pattern("Object Deleted", bucket)
  end

  @doc """
  Builds an EventBridge event pattern matching all S3 events for a bucket.

  Unlike `s3_object_created_pattern/1` and `s3_object_deleted_pattern/1`, this matches
  every S3 event type (created, deleted, restore, replication, etc.).

  ## Examples

      iex> AWS.EventBridge.s3_all_events_pattern("my-bucket")
      %{"source" => ["aws.s3"], "detail" => %{"bucket" => %{"name" => ["my-bucket"]}}}
  """
  @spec s3_all_events_pattern(bucket :: String.t()) :: map()
  def s3_all_events_pattern(bucket) do
    %{
      "source" => ["aws.s3"],
      "detail" => %{
        "bucket" => %{
          "name" => [bucket]
        }
      }
    }
  end

  @doc """
  Builds an EventBridge event pattern for any S3 event type.

  ## Examples

      iex> AWS.EventBridge.s3_event_pattern("Object Deleted", "my-bucket")
      %{"source" => ["aws.s3"], "detail-type" => ["Object Deleted"], "detail" => %{"bucket" => %{"name" => ["my-bucket"]}}}
  """
  @spec s3_event_pattern(detail_type :: String.t(), bucket :: String.t()) :: map()
  def s3_event_pattern(detail_type, bucket) do
    %{
      "source" => ["aws.s3"],
      "detail-type" => [detail_type],
      "detail" => %{
        "bucket" => %{
          "name" => [bucket]
        }
      }
    }
  end

  # Sandbox delegation

  defp inline_sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    sandbox_enabled = sandbox_opts[:enabled] || Config.sandbox_enabled?()
    sandbox_mode = sandbox_opts[:mode] || Config.sandbox_mode()

    sandbox_enabled and sandbox_mode === :inline and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    @doc false
    defdelegate sandbox_disabled?, to: AWS.EventBridge.Sandbox

    # Rule management
    @doc false
    defdelegate sandbox_put_rule_response(name, opts), to: AWS.EventBridge.Sandbox, as: :put_rule_response
    @doc false
    defdelegate sandbox_describe_rule_response(name, opts), to: AWS.EventBridge.Sandbox, as: :describe_rule_response
    @doc false
    defdelegate sandbox_list_rules_response(opts), to: AWS.EventBridge.Sandbox, as: :list_rules_response
    @doc false
    defdelegate sandbox_delete_rule_response(name, opts), to: AWS.EventBridge.Sandbox, as: :delete_rule_response

    # Target management
    @doc false
    defdelegate sandbox_put_targets_response(rule, targets, opts), to: AWS.EventBridge.Sandbox, as: :put_targets_response
    @doc false
    defdelegate sandbox_list_targets_by_rule_response(rule, opts), to: AWS.EventBridge.Sandbox, as: :list_targets_by_rule_response
    @doc false
    defdelegate sandbox_remove_targets_response(rule, ids, opts), to: AWS.EventBridge.Sandbox, as: :remove_targets_response

    # Connection management
    @doc false
    defdelegate sandbox_create_connection_response(name, auth_type, auth_params, opts), to: AWS.EventBridge.Sandbox, as: :create_connection_response
    @doc false
    defdelegate sandbox_describe_connection_response(name, opts), to: AWS.EventBridge.Sandbox, as: :describe_connection_response
    @doc false
    defdelegate sandbox_update_connection_response(name, opts), to: AWS.EventBridge.Sandbox, as: :update_connection_response
    @doc false
    defdelegate sandbox_delete_connection_response(name, opts), to: AWS.EventBridge.Sandbox, as: :delete_connection_response
    @doc false
    defdelegate sandbox_list_connections_response(opts), to: AWS.EventBridge.Sandbox, as: :list_connections_response

    # API Destination management
    @doc false
    defdelegate sandbox_create_api_destination_response(name, conn_arn, endpoint, method, opts), to: AWS.EventBridge.Sandbox, as: :create_api_destination_response
    @doc false
    defdelegate sandbox_describe_api_destination_response(name, opts), to: AWS.EventBridge.Sandbox, as: :describe_api_destination_response
    @doc false
    defdelegate sandbox_update_api_destination_response(name, opts), to: AWS.EventBridge.Sandbox, as: :update_api_destination_response
    @doc false
    defdelegate sandbox_delete_api_destination_response(name, opts), to: AWS.EventBridge.Sandbox, as: :delete_api_destination_response
    @doc false
    defdelegate sandbox_list_api_destinations_response(opts), to: AWS.EventBridge.Sandbox, as: :list_api_destinations_response

    # Event Bus management
    @doc false
    defdelegate sandbox_create_event_bus_response(name, opts), to: AWS.EventBridge.Sandbox, as: :create_event_bus_response
    @doc false
    defdelegate sandbox_describe_event_bus_response(name, opts), to: AWS.EventBridge.Sandbox, as: :describe_event_bus_response
    @doc false
    defdelegate sandbox_delete_event_bus_response(name, opts), to: AWS.EventBridge.Sandbox, as: :delete_event_bus_response
    @doc false
    defdelegate sandbox_list_event_buses_response(opts), to: AWS.EventBridge.Sandbox, as: :list_event_buses_response

    # Events
    @doc false
    defdelegate sandbox_put_events_response(entries, opts), to: AWS.EventBridge.Sandbox, as: :put_events_response

    # Rule control
    @doc false
    defdelegate sandbox_enable_rule_response(name, opts), to: AWS.EventBridge.Sandbox, as: :enable_rule_response
    @doc false
    defdelegate sandbox_disable_rule_response(name, opts), to: AWS.EventBridge.Sandbox, as: :disable_rule_response
  else
    defp sandbox_disabled?, do: true

    defp sandbox_put_rule_response(_, _), do: raise("sandbox not available")
    defp sandbox_describe_rule_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_rules_response(_), do: raise("sandbox not available")
    defp sandbox_delete_rule_response(_, _), do: raise("sandbox not available")
    defp sandbox_put_targets_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_list_targets_by_rule_response(_, _), do: raise("sandbox not available")
    defp sandbox_remove_targets_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_create_connection_response(_, _, _, _), do: raise("sandbox not available")
    defp sandbox_describe_connection_response(_, _), do: raise("sandbox not available")
    defp sandbox_update_connection_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_connection_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_connections_response(_), do: raise("sandbox not available")
    defp sandbox_create_api_destination_response(_, _, _, _, _), do: raise("sandbox not available")
    defp sandbox_describe_api_destination_response(_, _), do: raise("sandbox not available")
    defp sandbox_update_api_destination_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_api_destination_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_api_destinations_response(_), do: raise("sandbox not available")
    defp sandbox_create_event_bus_response(_, _), do: raise("sandbox not available")
    defp sandbox_describe_event_bus_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_event_bus_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_event_buses_response(_), do: raise("sandbox not available")
    defp sandbox_put_events_response(_, _), do: raise("sandbox not available")
    defp sandbox_enable_rule_response(_, _), do: raise("sandbox not available")
    defp sandbox_disable_rule_response(_, _), do: raise("sandbox not available")
  end

  # Private helpers

  defp build_operation(action, data) do
    %ExAws.Operation.JSON{
      http_method: :post,
      service: :events,
      headers: [
        {"x-amz-target", "AWSEvents.#{action}"},
        {"content-type", "application/x-amz-json-1.1"}
      ],
      data: data
    }
  end

  defp perform(operation, opts) do
    ExAws.Operation.perform(operation, events_config(opts))
  end

  defp events_config(opts) do
    {events_opts, opts} = Keyword.pop(opts, :events, [])
    {sandbox_opts, opts} = Keyword.pop(opts, :sandbox, [])

    overrides =
      events_opts
      |> Keyword.put_new(:region, opts[:region] || Config.region())
      |> configure_endpoint(sandbox_opts)

    ExAws.Config.new(:events, overrides)
  end

  defp configure_endpoint(events_opts, sandbox_opts) do
    sandbox_enabled = sandbox_opts[:enabled] || Config.sandbox_enabled?()
    sandbox_mode = sandbox_opts[:mode] || Config.sandbox_mode()

    if sandbox_enabled and sandbox_mode === :local do
      events_opts
      |> Keyword.put(:scheme, Config.sandbox_scheme())
      |> Keyword.put(:host, Config.sandbox_host())
      |> Keyword.put(:port, Config.sandbox_port())
      |> Keyword.put_new(:access_key_id, "test")
      |> Keyword.put_new(:secret_access_key, "test")
    else
      maybe_put_credentials(events_opts)
    end
  end

  defp maybe_put_credentials(opts) do
    opts
    |> Keyword.put_new(:access_key_id, Config.access_key_id())
    |> Keyword.put_new(:secret_access_key, Config.secret_access_key())
  end

  defp deserialize_response({:ok, response}, _opts, func) do
    case func.(response) do
      {:error, _} = error -> error
      {:ok, _} = ok -> ok
      result -> {:ok, result}
    end
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code in 400..499 do
    {:error, Error.not_found("resource not found.", %{response: response}, opts)}
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code >= 500 do
    {:error, Error.service_unavailable("service temporarily unavailable", %{response: response}, opts)}
  end

  defp deserialize_response({:error, reason}, opts, _func) do
    {:error, Error.internal_server_error("internal server error", %{reason: reason}, opts)}
  end

  defp compact(kw), do: Enum.reject(kw, fn {_, v} -> is_nil(v) end)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, false), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
  defp maybe_put(map, key, value, transform), do: Map.put(map, key, transform.(value))

  defp camelize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {camelize(k), camelize_keys(v)} end)
  end

  defp camelize_keys(list) when is_list(list), do: Enum.map(list, &camelize_keys/1)
  defp camelize_keys(other), do: other

  defp camelize(key) when is_atom(key), do: key |> Atom.to_string() |> Recase.to_pascal()
  defp camelize(key) when is_binary(key), do: Recase.to_pascal(key)
end
