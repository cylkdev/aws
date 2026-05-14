defmodule AWS.AutoScaling do
  @moduledoc """
  `AWS.AutoScaling` provides an API for AWS EC2 Auto Scaling.

  This module calls the AWS Auto Scaling Query API directly via `AWS.HTTP`
  and `AWS.Signer` (through `AWS.Client`).

  Auto Scaling's public API is XML-only at the AWS wire level. The service
  model (`botocore/data/autoscaling/2011-01-01/service-2.json`) declares
  `metadata.protocols = ["query"]`, and AWS does not expose a JSON Auto
  Scaling endpoint. The form-urlencoded request / XML response handling
  here (XPath extraction via `SweetXml`) is a consequence of AWS's
  protocol choice, not a library decision.

  Auto Scaling is a regional service; requests are routed to
  `autoscaling.{region}.amazonaws.com`.

  ## Shared Options

  Credentials and region are flat top-level opts on every call (ex_aws shape).
  Each accepts a literal, a source tuple, or a list of sources (first
  non-nil wins):

    - `:access_key_id`, `:secret_access_key`, `:security_token`, `:region` -
      Sources: literal binary, `{:system, "ENV"}`, `:instance_role`,
      `:ecs_task_role`, `{:awscli, profile}` / `{:awscli, profile, ttl}`,
      a module, or a list of any of these.

  The following options are also available:

    - `:auto_scaling` - A keyword list of Auto Scaling endpoint overrides.
      Supported keys: `:scheme`, `:host`, `:port`. Credentials are not
      read from this sub-list; use the top-level keys above.

    - `:sandbox` - A keyword list to override sandbox configuration
      (`:enabled`, `:mode` (`:local` | `:inline`), `:scheme`, `:host`,
      `:port`).

  ## Sandbox

  Set `sandbox: [enabled: true, mode: :inline]` to activate inline sandbox mode.

  Add the following to your `test_helper.exs`:

      AWS.AutoScaling.Sandbox.start_link()

  Then register per-test response functions, e.g.:

      AWS.AutoScaling.Sandbox.set_describe_auto_scaling_groups_responses([
        {"*", fn -> {:ok, %{auto_scaling_groups: [], next_token: nil}} end}
      ])
  """

  import SweetXml, only: [xpath: 2, xpath: 3, sigil_x: 2]

  alias AWS.AutoScaling.Operation
  alias AWS.Client
  alias AWS.Config

  @service "autoscaling"
  @content_type "application/x-www-form-urlencoded"
  @api_version "2011-01-01"
  @default_region "us-east-1"

  @override_keys [:headers, :body, :http, :url]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Describes Auto Scaling groups.

  Maps to AWS `DescribeAutoScalingGroups`.

  ## Options

    - `:auto_scaling_group_names` - list of ASG names
    - `:filters` - list of `%{name: ..., values: [...]}` maps
    - `:max_records` - integer
    - `:next_token` - pagination token
    - `:include_instances` - boolean

  See `AWS.AutoScaling` shared options for credentials / region / endpoint.
  """
  @spec describe_auto_scaling_groups(keyword) :: {:ok, map} | {:error, term}
  def describe_auto_scaling_groups(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_auto_scaling_groups_response(opts)
    else
      do_describe_auto_scaling_groups(opts)
    end
  end

  defp do_describe_auto_scaling_groups(opts) do
    params =
      flatten_query(%{
        "AutoScalingGroupNames" => opts[:auto_scaling_group_names],
        "Filters" => opts[:filters],
        "MaxRecords" => opts[:max_records],
        "NextToken" => opts[:next_token],
        "IncludeInstances" => opts[:include_instances]
      })

    "DescribeAutoScalingGroups"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_describe_auto_scaling_groups/1)
  end

  @doc """
  Describes Auto Scaling instances.

  Maps to AWS `DescribeAutoScalingInstances`.

  ## Options

    - `:instance_ids` - list of instance IDs
    - `:max_records` - integer
    - `:next_token` - pagination token
  """
  @spec describe_auto_scaling_instances(keyword) :: {:ok, map} | {:error, term}
  def describe_auto_scaling_instances(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_auto_scaling_instances_response(opts)
    else
      do_describe_auto_scaling_instances(opts)
    end
  end

  defp do_describe_auto_scaling_instances(opts) do
    params =
      flatten_query(%{
        "InstanceIds" => opts[:instance_ids],
        "MaxRecords" => opts[:max_records],
        "NextToken" => opts[:next_token]
      })

    "DescribeAutoScalingInstances"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_describe_auto_scaling_instances/1)
  end

  @doc """
  Describes instance refreshes for an Auto Scaling group.

  Maps to AWS `DescribeInstanceRefreshes`. `auto_scaling_group_name` is required.

  ## Options

    - `:instance_refresh_ids` - list of refresh IDs
    - `:max_records` - integer
    - `:next_token` - pagination token
  """
  @spec describe_instance_refreshes(String.t(), keyword) :: {:ok, map} | {:error, term}
  def describe_instance_refreshes(auto_scaling_group_name, opts \\ [])
      when is_binary(auto_scaling_group_name) do
    if inline_sandbox?(opts) do
      sandbox_describe_instance_refreshes_response(auto_scaling_group_name, opts)
    else
      do_describe_instance_refreshes(auto_scaling_group_name, opts)
    end
  end

  defp do_describe_instance_refreshes(auto_scaling_group_name, opts) do
    params =
      flatten_query(%{
        "AutoScalingGroupName" => auto_scaling_group_name,
        "InstanceRefreshIds" => opts[:instance_refresh_ids],
        "MaxRecords" => opts[:max_records],
        "NextToken" => opts[:next_token]
      })

    "DescribeInstanceRefreshes"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_describe_instance_refreshes/1)
  end

  @doc """
  Starts an instance refresh for an Auto Scaling group.

  Maps to AWS `StartInstanceRefresh`. `auto_scaling_group_name` is required.

  ## Options

    - `:strategy` - refresh strategy (e.g. `"Rolling"`)
    - `:preferences` - map passed verbatim to AWS `Preferences` (any field
      AWS accepts; flattened by the generic Query encoder)
    - `:desired_configuration` - map passed verbatim to AWS
      `DesiredConfiguration`
  """
  @spec start_instance_refresh(String.t(), keyword) :: {:ok, map} | {:error, term}
  def start_instance_refresh(auto_scaling_group_name, opts \\ [])
      when is_binary(auto_scaling_group_name) do
    if inline_sandbox?(opts) do
      sandbox_start_instance_refresh_response(auto_scaling_group_name, opts)
    else
      do_start_instance_refresh(auto_scaling_group_name, opts)
    end
  end

  defp do_start_instance_refresh(auto_scaling_group_name, opts) do
    params =
      flatten_query(%{
        "AutoScalingGroupName" => auto_scaling_group_name,
        "Strategy" => opts[:strategy],
        "Preferences" => opts[:preferences],
        "DesiredConfiguration" => opts[:desired_configuration]
      })

    "StartInstanceRefresh"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_start_instance_refresh/1)
  end

  @doc """
  Cancels an in-progress instance refresh.

  Maps to AWS `CancelInstanceRefresh`. `auto_scaling_group_name` is required.
  """
  @spec cancel_instance_refresh(String.t(), keyword) :: {:ok, map} | {:error, term}
  def cancel_instance_refresh(auto_scaling_group_name, opts \\ [])
      when is_binary(auto_scaling_group_name) do
    if inline_sandbox?(opts) do
      sandbox_cancel_instance_refresh_response(auto_scaling_group_name, opts)
    else
      do_cancel_instance_refresh(auto_scaling_group_name, opts)
    end
  end

  defp do_cancel_instance_refresh(auto_scaling_group_name, opts) do
    params = flatten_query(%{"AutoScalingGroupName" => auto_scaling_group_name})

    "CancelInstanceRefresh"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_cancel_instance_refresh/1)
  end

  @doc """
  Rolls back an in-progress or recent instance refresh.

  Maps to AWS `RollbackInstanceRefresh`. `auto_scaling_group_name` is required.
  """
  @spec rollback_instance_refresh(String.t(), keyword) :: {:ok, map} | {:error, term}
  def rollback_instance_refresh(auto_scaling_group_name, opts \\ [])
      when is_binary(auto_scaling_group_name) do
    if inline_sandbox?(opts) do
      sandbox_rollback_instance_refresh_response(auto_scaling_group_name, opts)
    else
      do_rollback_instance_refresh(auto_scaling_group_name, opts)
    end
  end

  defp do_rollback_instance_refresh(auto_scaling_group_name, opts) do
    params = flatten_query(%{"AutoScalingGroupName" => auto_scaling_group_name})

    "RollbackInstanceRefresh"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_rollback_instance_refresh/1)
  end

  @doc """
  Completes a pending lifecycle action.

  Maps to AWS `CompleteLifecycleAction`.

  ## Required keys in `opts`

    - `:lifecycle_hook_name`
    - `:auto_scaling_group_name`
    - `:lifecycle_action_result` (`"CONTINUE"` or `"ABANDON"`)

  ## Optional keys

    - `:lifecycle_action_token`
    - `:instance_id`
  """
  @spec complete_lifecycle_action(keyword) :: {:ok, map} | {:error, term}
  def complete_lifecycle_action(opts) do
    require_opts!(opts, [
      :lifecycle_hook_name,
      :auto_scaling_group_name,
      :lifecycle_action_result
    ])

    if inline_sandbox?(opts) do
      sandbox_complete_lifecycle_action_response(opts)
    else
      do_complete_lifecycle_action(opts)
    end
  end

  defp do_complete_lifecycle_action(opts) do
    params =
      flatten_query(%{
        "LifecycleHookName" => opts[:lifecycle_hook_name],
        "AutoScalingGroupName" => opts[:auto_scaling_group_name],
        "LifecycleActionResult" => opts[:lifecycle_action_result],
        "LifecycleActionToken" => opts[:lifecycle_action_token],
        "InstanceId" => opts[:instance_id]
      })

    "CompleteLifecycleAction"
    |> perform(params, opts)
    |> deserialize_response(opts, fn _body -> %{} end)
  end

  @doc """
  Records a heartbeat for a pending lifecycle action.

  Maps to AWS `RecordLifecycleActionHeartbeat`.

  ## Required keys in `opts`

    - `:lifecycle_hook_name`
    - `:auto_scaling_group_name`

  ## Optional keys

    - `:lifecycle_action_token`
    - `:instance_id`
  """
  @spec record_lifecycle_action_heartbeat(keyword) :: {:ok, map} | {:error, term}
  def record_lifecycle_action_heartbeat(opts) do
    require_opts!(opts, [:lifecycle_hook_name, :auto_scaling_group_name])

    if inline_sandbox?(opts) do
      sandbox_record_lifecycle_action_heartbeat_response(opts)
    else
      do_record_lifecycle_action_heartbeat(opts)
    end
  end

  defp do_record_lifecycle_action_heartbeat(opts) do
    params =
      flatten_query(%{
        "LifecycleHookName" => opts[:lifecycle_hook_name],
        "AutoScalingGroupName" => opts[:auto_scaling_group_name],
        "LifecycleActionToken" => opts[:lifecycle_action_token],
        "InstanceId" => opts[:instance_id]
      })

    "RecordLifecycleActionHeartbeat"
    |> perform(params, opts)
    |> deserialize_response(opts, fn _body -> %{} end)
  end

  defp require_opts!(opts, keys) do
    Enum.each(keys, fn key ->
      if is_nil(opts[key]) do
        raise ArgumentError, "missing required option #{inspect(key)}"
      end
    end)
  end

  @doc """
  Sets the health status for an instance.

  Maps to AWS `SetInstanceHealth`.

  ## Options

    - `:should_respect_grace_period` - boolean
  """
  @spec set_instance_health(String.t(), String.t(), keyword) :: {:ok, map} | {:error, term}
  def set_instance_health(instance_id, health_status, opts \\ [])
      when is_binary(instance_id) and is_binary(health_status) do
    if inline_sandbox?(opts) do
      sandbox_set_instance_health_response(instance_id, health_status, opts)
    else
      do_set_instance_health(instance_id, health_status, opts)
    end
  end

  defp do_set_instance_health(instance_id, health_status, opts) do
    params =
      flatten_query(%{
        "InstanceId" => instance_id,
        "HealthStatus" => health_status,
        "ShouldRespectGracePeriod" => opts[:should_respect_grace_period]
      })

    "SetInstanceHealth"
    |> perform(params, opts)
    |> deserialize_response(opts, fn _body -> %{} end)
  end

  @doc """
  Terminates an instance within an Auto Scaling group.

  Maps to AWS `TerminateInstanceInAutoScalingGroup`.
  `should_decrement_desired_capacity` is required and must be a boolean.

  Returns the resulting `Activity` from AWS as a map under `:activity`.
  """
  @spec terminate_instance_in_auto_scaling_group(String.t(), boolean, keyword) ::
          {:ok, map} | {:error, term}
  def terminate_instance_in_auto_scaling_group(
        instance_id,
        should_decrement_desired_capacity,
        opts \\ []
      )
      when is_binary(instance_id) and is_boolean(should_decrement_desired_capacity) do
    if inline_sandbox?(opts) do
      sandbox_terminate_instance_in_auto_scaling_group_response(
        instance_id,
        should_decrement_desired_capacity,
        opts
      )
    else
      do_terminate_instance_in_auto_scaling_group(
        instance_id,
        should_decrement_desired_capacity,
        opts
      )
    end
  end

  defp do_terminate_instance_in_auto_scaling_group(
         instance_id,
         should_decrement_desired_capacity,
         opts
       ) do
    params =
      flatten_query(%{
        "InstanceId" => instance_id,
        "ShouldDecrementDesiredCapacity" => should_decrement_desired_capacity
      })

    "TerminateInstanceInAutoScalingGroup"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_terminate_instance_in_auto_scaling_group/1)
  end

  @doc """
  Sets the desired capacity for an Auto Scaling group.

  Maps to AWS `SetDesiredCapacity`.

  ## Options

    - `:honor_cooldown` - boolean
  """
  @spec set_desired_capacity(String.t(), integer, keyword) :: {:ok, map} | {:error, term}
  def set_desired_capacity(auto_scaling_group_name, desired_capacity, opts \\ [])
      when is_binary(auto_scaling_group_name) and is_integer(desired_capacity) do
    if inline_sandbox?(opts) do
      sandbox_set_desired_capacity_response(auto_scaling_group_name, desired_capacity, opts)
    else
      do_set_desired_capacity(auto_scaling_group_name, desired_capacity, opts)
    end
  end

  defp do_set_desired_capacity(auto_scaling_group_name, desired_capacity, opts) do
    params =
      flatten_query(%{
        "AutoScalingGroupName" => auto_scaling_group_name,
        "DesiredCapacity" => desired_capacity,
        "HonorCooldown" => opts[:honor_cooldown]
      })

    "SetDesiredCapacity"
    |> perform(params, opts)
    |> deserialize_response(opts, fn _body -> %{} end)
  end

  # ---------------------------------------------------------------------------
  # Request building
  # ---------------------------------------------------------------------------

  @doc false
  def build_operation(action, params, opts) do
    opts = Keyword.put_new(opts, :region, @default_region)

    with {:ok, config} <- Client.resolve_config(:auto_scaling, opts, &default_host/1) do
      op = %Operation{
        method: :post,
        url: Client.simple_url(config),
        headers: [{"content-type", @content_type}],
        body: encode_body(action, params),
        service: @service,
        region: config.region,
        access_key_id: config.access_key_id,
        secret_access_key: config.secret_access_key,
        security_token: config.security_token,
        http: Keyword.get(opts, :http, [])
      }

      {:ok, apply_overrides(op, opts[:auto_scaling] || [])}
    end
  end

  defp default_host(region), do: "autoscaling.#{region}.amazonaws.com"

  defp perform(action, params, opts) do
    with {:ok, op} <- build_operation(action, params, opts) do
      case Client.execute(op) do
        {:ok, %{body: body}} -> {:ok, body}
        {:error, _} = err -> err
      end
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

  defp encode_body(action, params) do
    params
    |> Map.merge(%{"Action" => action, "Version" => @api_version})
    |> URI.encode_query()
  end

  # ---------------------------------------------------------------------------
  # Generic AWS Query-protocol flattener
  #
  # Turns a nested map keyed by AWS PascalCase strings (or snake_case
  # atoms — auto-converted) into the flat string-keyed map that
  # `URI.encode_query/1` expects:
  #
  #     scalar         -> "Key=Value"
  #     nil / []       -> dropped
  #     [scalar, ...]  -> "Key.member.N=Value"
  #     %{...}         -> "Key.SubKey=Value"  (recursively)
  #     [%{...}, ...]  -> "Key.member.N.SubKey=Value"
  #
  # No operation in this module hand-rolls body encoding; every public
  # function builds an input map and passes it through `flatten_query/1`.
  # ---------------------------------------------------------------------------

  @doc false
  def flatten_query(input) when is_map(input) do
    Enum.reduce(input, %{}, fn {k, v}, acc -> put_query(acc, pascal(k), v) end)
  end

  defp put_query(acc, _key, nil), do: acc
  defp put_query(acc, _key, []), do: acc

  defp put_query(acc, key, list) when is_list(list) do
    list
    |> Enum.with_index(1)
    |> Enum.reduce(acc, fn {item, idx}, inner ->
      put_query(inner, "#{key}.member.#{idx}", item)
    end)
  end

  defp put_query(acc, key, map) when is_map(map) do
    Enum.reduce(map, acc, fn {sub_k, sub_v}, inner ->
      put_query(inner, "#{key}.#{pascal(sub_k)}", sub_v)
    end)
  end

  defp put_query(acc, key, value) when is_boolean(value),
    do: Map.put(acc, key, to_string(value))

  defp put_query(acc, key, value) when is_atom(value),
    do: Map.put(acc, key, Atom.to_string(value))

  defp put_query(acc, key, value), do: Map.put(acc, key, to_string(value))

  defp pascal(key) when is_binary(key), do: key
  defp pascal(key) when is_atom(key), do: key |> Atom.to_string() |> Recase.to_pascal()

  # ---------------------------------------------------------------------------
  # Response error wrapping
  # ---------------------------------------------------------------------------

  defp deserialize_response({:ok, body}, _opts, parser) do
    case parser.(body) do
      {:error, _} = error -> error
      {:ok, _} = ok -> ok
      result -> {:ok, result}
    end
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, _opts, _parser)
       when status_code in 400..499 do
    {:error, ErrorMessage.not_found("resource not found.", %{response: response})}
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, _opts, _parser)
       when status_code >= 500 do
    {:error,
     ErrorMessage.service_unavailable("service temporarily unavailable", %{response: response})}
  end

  defp deserialize_response({:error, reason}, _opts, _parser) do
    {:error, ErrorMessage.internal_server_error("internal server error", %{reason: reason})}
  end

  # ---------------------------------------------------------------------------
  # Sandbox delegation
  # ---------------------------------------------------------------------------

  defp inline_sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    cfg = Config.sandbox()
    enabled = Keyword.get(sandbox_opts, :enabled, cfg[:enabled])
    mode = Keyword.get(sandbox_opts, :mode, cfg[:mode])

    enabled and mode === :inline and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    @doc false
    defdelegate sandbox_disabled?, to: AWS.AutoScaling.Sandbox

    @doc false
    defdelegate sandbox_describe_auto_scaling_groups_response(opts),
      to: AWS.AutoScaling.Sandbox,
      as: :describe_auto_scaling_groups_response

    @doc false
    defdelegate sandbox_describe_auto_scaling_instances_response(opts),
      to: AWS.AutoScaling.Sandbox,
      as: :describe_auto_scaling_instances_response

    @doc false
    defdelegate sandbox_describe_instance_refreshes_response(asg, opts),
      to: AWS.AutoScaling.Sandbox,
      as: :describe_instance_refreshes_response

    @doc false
    defdelegate sandbox_start_instance_refresh_response(asg, opts),
      to: AWS.AutoScaling.Sandbox,
      as: :start_instance_refresh_response

    @doc false
    defdelegate sandbox_cancel_instance_refresh_response(asg, opts),
      to: AWS.AutoScaling.Sandbox,
      as: :cancel_instance_refresh_response

    @doc false
    defdelegate sandbox_rollback_instance_refresh_response(asg, opts),
      to: AWS.AutoScaling.Sandbox,
      as: :rollback_instance_refresh_response

    @doc false
    defdelegate sandbox_complete_lifecycle_action_response(opts),
      to: AWS.AutoScaling.Sandbox,
      as: :complete_lifecycle_action_response

    @doc false
    defdelegate sandbox_record_lifecycle_action_heartbeat_response(opts),
      to: AWS.AutoScaling.Sandbox,
      as: :record_lifecycle_action_heartbeat_response

    @doc false
    defdelegate sandbox_set_instance_health_response(instance_id, health_status, opts),
      to: AWS.AutoScaling.Sandbox,
      as: :set_instance_health_response

    @doc false
    defdelegate sandbox_terminate_instance_in_auto_scaling_group_response(
                  instance_id,
                  should_decrement,
                  opts
                ),
                to: AWS.AutoScaling.Sandbox,
                as: :terminate_instance_in_auto_scaling_group_response

    @doc false
    defdelegate sandbox_set_desired_capacity_response(asg, desired, opts),
      to: AWS.AutoScaling.Sandbox,
      as: :set_desired_capacity_response
  else
    @sandbox_unavailable "sandbox not available; add :sandbox_registry as a dep"

    defp sandbox_disabled?, do: false
    defp sandbox_describe_auto_scaling_groups_response(_o), do: raise(@sandbox_unavailable)
    defp sandbox_describe_auto_scaling_instances_response(_o), do: raise(@sandbox_unavailable)
    defp sandbox_describe_instance_refreshes_response(_a, _o), do: raise(@sandbox_unavailable)
    defp sandbox_start_instance_refresh_response(_a, _o), do: raise(@sandbox_unavailable)
    defp sandbox_cancel_instance_refresh_response(_a, _o), do: raise(@sandbox_unavailable)
    defp sandbox_rollback_instance_refresh_response(_a, _o), do: raise(@sandbox_unavailable)
    defp sandbox_complete_lifecycle_action_response(_o), do: raise(@sandbox_unavailable)
    defp sandbox_record_lifecycle_action_heartbeat_response(_o), do: raise(@sandbox_unavailable)
    defp sandbox_set_instance_health_response(_i, _h, _o), do: raise(@sandbox_unavailable)

    defp sandbox_terminate_instance_in_auto_scaling_group_response(_i, _d, _o),
      do: raise(@sandbox_unavailable)

    defp sandbox_set_desired_capacity_response(_a, _d, _o), do: raise(@sandbox_unavailable)
  end

  # ---------------------------------------------------------------------------
  # XML parsers
  # ---------------------------------------------------------------------------

  defp parse_describe_auto_scaling_groups(body) do
    result =
      xpath(body, ~x"//DescribeAutoScalingGroupsResult"e,
        groups: [
          ~x"./AutoScalingGroups/member"l,
          auto_scaling_group_name: ~x"./AutoScalingGroupName/text()"s,
          auto_scaling_group_arn: ~x"./AutoScalingGroupARN/text()"s,
          launch_configuration_name: ~x"./LaunchConfigurationName/text()"s,
          min_size: ~x"./MinSize/text()"i,
          max_size: ~x"./MaxSize/text()"i,
          desired_capacity: ~x"./DesiredCapacity/text()"i,
          default_cooldown: ~x"./DefaultCooldown/text()"i,
          availability_zones: ~x"./AvailabilityZones/member/text()"sl,
          load_balancer_names: ~x"./LoadBalancerNames/member/text()"sl,
          target_group_arns: ~x"./TargetGroupARNs/member/text()"sl,
          health_check_type: ~x"./HealthCheckType/text()"s,
          health_check_grace_period: ~x"./HealthCheckGracePeriod/text()"oi,
          created_time: ~x"./CreatedTime/text()"s,
          vpc_zone_identifier: ~x"./VPCZoneIdentifier/text()"s,
          service_linked_role_arn: ~x"./ServiceLinkedRoleARN/text()"s,
          new_instances_protected_from_scale_in: ~x"./NewInstancesProtectedFromScaleIn/text()"s,
          termination_policies: ~x"./TerminationPolicies/member/text()"sl,
          instances: [
            ~x"./Instances/member"l,
            instance_id: ~x"./InstanceId/text()"s,
            instance_type: ~x"./InstanceType/text()"s,
            availability_zone: ~x"./AvailabilityZone/text()"s,
            lifecycle_state: ~x"./LifecycleState/text()"s,
            health_status: ~x"./HealthStatus/text()"s,
            launch_configuration_name: ~x"./LaunchConfigurationName/text()"s,
            protected_from_scale_in: ~x"./ProtectedFromScaleIn/text()"s
          ]
        ],
        next_token: ~x"./NextToken/text()"s
      )

    groups =
      Enum.map(result.groups, fn g ->
        g
        |> Map.update!(:new_instances_protected_from_scale_in, &boolish/1)
        |> Map.update!(:instances, fn instances ->
          Enum.map(instances, fn i ->
            Map.update!(i, :protected_from_scale_in, &(&1 === "true"))
          end)
        end)
      end)

    %{auto_scaling_groups: groups, next_token: nilify(result.next_token)}
  end

  defp boolish("true"), do: true
  defp boolish("false"), do: false
  defp boolish(""), do: nil
  defp boolish(other), do: other

  defp parse_describe_auto_scaling_instances(body) do
    result =
      xpath(body, ~x"//DescribeAutoScalingInstancesResult"e,
        instances: [
          ~x"./AutoScalingInstances/member"l,
          instance_id: ~x"./InstanceId/text()"s,
          auto_scaling_group_name: ~x"./AutoScalingGroupName/text()"s,
          availability_zone: ~x"./AvailabilityZone/text()"s,
          lifecycle_state: ~x"./LifecycleState/text()"s,
          health_status: ~x"./HealthStatus/text()"s,
          launch_configuration_name: ~x"./LaunchConfigurationName/text()"s,
          instance_type: ~x"./InstanceType/text()"s,
          protected_from_scale_in: ~x"./ProtectedFromScaleIn/text()"s
        ],
        next_token: ~x"./NextToken/text()"s
      )

    instances =
      Enum.map(result.instances, fn i ->
        Map.update!(i, :protected_from_scale_in, &(&1 === "true"))
      end)

    %{auto_scaling_instances: instances, next_token: nilify(result.next_token)}
  end

  defp parse_describe_instance_refreshes(body) do
    result =
      xpath(body, ~x"//DescribeInstanceRefreshesResult"e,
        instance_refreshes: [
          ~x"./InstanceRefreshes/member"l,
          instance_refresh_id: ~x"./InstanceRefreshId/text()"s,
          auto_scaling_group_name: ~x"./AutoScalingGroupName/text()"s,
          status: ~x"./Status/text()"s,
          status_reason: ~x"./StatusReason/text()"s,
          start_time: ~x"./StartTime/text()"s,
          end_time: ~x"./EndTime/text()"s,
          percentage_complete: ~x"./PercentageComplete/text()"oi,
          instances_to_update: ~x"./InstancesToUpdate/text()"oi,
          preferences: ~x"./Preferences/text()"s
        ],
        next_token: ~x"./NextToken/text()"s
      )

    %{
      instance_refreshes: result.instance_refreshes,
      next_token: nilify(result.next_token)
    }
  end

  defp parse_start_instance_refresh(body) do
    %{
      instance_refresh_id: xpath(body, ~x"//StartInstanceRefreshResult/InstanceRefreshId/text()"s)
    }
  end

  defp parse_cancel_instance_refresh(body) do
    %{
      instance_refresh_id:
        xpath(body, ~x"//CancelInstanceRefreshResult/InstanceRefreshId/text()"s)
    }
  end

  defp parse_rollback_instance_refresh(body) do
    %{
      instance_refresh_id:
        xpath(body, ~x"//RollbackInstanceRefreshResult/InstanceRefreshId/text()"s)
    }
  end

  defp parse_terminate_instance_in_auto_scaling_group(body) do
    activity =
      xpath(body, ~x"//TerminateInstanceInAutoScalingGroupResult/Activity"e,
        activity_id: ~x"./ActivityId/text()"s,
        auto_scaling_group_name: ~x"./AutoScalingGroupName/text()"s,
        cause: ~x"./Cause/text()"s,
        description: ~x"./Description/text()"s,
        details: ~x"./Details/text()"s,
        progress: ~x"./Progress/text()"oi,
        status_code: ~x"./StatusCode/text()"s,
        start_time: ~x"./StartTime/text()"s
      )

    %{activity: activity}
  end

  defp nilify(""), do: nil
  defp nilify(other), do: other
end
