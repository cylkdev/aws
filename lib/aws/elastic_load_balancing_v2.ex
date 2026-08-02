defmodule AWS.ElasticLoadBalancingV2 do
  @moduledoc """
  `AWS.ElasticLoadBalancingV2` provides an API for AWS Elastic Load
  Balancing v2 (Application, Network, and Gateway Load Balancers).

  This module calls the AWS ELBv2 Query API directly via `AWS.HTTP` and
  `AWS.Signer` (through `AWS.Client`).

  ELBv2's public API is XML-only at the AWS wire level. The service
  model (`botocore/data/elasticloadbalancingv2/2015-12-01/service-2.json`)
  declares `metadata.protocols = ["query"]`, and AWS does not expose a
  JSON ELBv2 endpoint. The form-urlencoded request / XML response
  handling here (XPath extraction via `SweetXml`) is a consequence of
  AWS's protocol choice, not a library decision.

  ELBv2 is a regional service; requests are routed to
  `elasticloadbalancing.{region}.amazonaws.com`. The SigV4 service
  identifier is `elasticloadbalancing` and the API version is
  `2015-12-01`.

  The operations needed by current callers are implemented:
  `describe_load_balancers/1`, `describe_listeners/2`,
  `describe_listeners_by_arns/2`, `describe_target_groups/1`,
  `describe_target_health/2`, `describe_rules/2`,
  `describe_rules_by_arns/2`, and `modify_rule/3`. `modify_rule/3` is the only
  mutating operation; load balancers, listeners, and target groups are
  expected to be declared elsewhere (e.g. terraform) and only read here.

  Inputs AWS requires for an operation are positional arguments; `opts`
  carries only optional inputs plus credentials, region, endpoint
  overrides, and the sandbox flag.

  ## Shared Options

  Credentials and region are flat top-level opts on every call (ex_aws shape).
  Each accepts a literal, a source tuple, or a list of sources (first
  non-nil wins):

    - `:access_key_id`, `:secret_access_key`, `:security_token`, `:region` -
      Sources: literal binary, `{:system, "ENV"}`, `:instance_role`,
      `:ecs_task_role`, `{:awscli, profile}` / `{:awscli, profile, ttl}`,
      a module, or a list of any of these.

  The following options are also available:

    - `:elastic_load_balancing_v2` - A keyword list of ELBv2 endpoint
      overrides. Supported keys: `:scheme`, `:host`, `:port`. Credentials
      are not read from this sub-list; use the top-level keys above.

    - `:sandbox` - A keyword list to override sandbox configuration
      (`:enabled`).

  ## Sandbox

  Set `sandbox: [enabled: true]` to activate inline sandbox
  mode.

  Add the following to your `test_helper.exs`:

      AWS.ElasticLoadBalancingV2.Sandbox.start_link()

  Then register per-test response functions, e.g.:

      AWS.ElasticLoadBalancingV2.Sandbox.set_describe_target_groups_responses([
        fn -> {:ok, %{target_groups: [], next_token: nil}} end
      ])
  """

  import SweetXml, only: [xpath: 3, sigil_x: 2]

  alias AWS.Client
  alias AWS.Config
  alias AWS.ElasticLoadBalancingV2.Operation

  @service "elasticloadbalancing"
  @content_type "application/x-www-form-urlencoded"
  @api_version "2015-12-01"
  @default_region "us-east-1"

  @override_keys [:headers, :body, :http, :url]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Describes target groups.

  Maps to AWS `DescribeTargetGroups`. v1 supports filtering by `:names`
  only; other selectors (`:target_group_arns`, `:load_balancer_arn`) are
  not exposed yet.

  ## Options

    - `:names` - list of target group names; encoded as `Names.member.N`
    - `:next_token` - pagination token (encoded as `Marker` on the wire)

  See `AWS.ElasticLoadBalancingV2` shared options for credentials /
  region / endpoint.

  ## Pagination

  Returns one page plus `:next_token`; the caller decides whether to
  follow it.
  """
  @spec describe_target_groups(opts :: keyword()) :: {:ok, map()} | {:error, term()}
  def describe_target_groups(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_target_groups_response(opts)
    else
      do_describe_target_groups(opts)
    end
  end

  defp do_describe_target_groups(opts) do
    params =
      flatten_query(%{
        "Names" => opts[:names],
        "Marker" => opts[:next_token]
      })

    "DescribeTargetGroups"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_describe_target_groups/1)
  end

  @doc """
  Describes the health of targets registered with a target group.

  Maps to AWS `DescribeTargetHealth`.

  ## Arguments

    - `target_group_arn` - target group ARN
    - `opts` - options below, plus shared credentials / region / endpoint

  ## Options

    - `:targets` - list of `%{id: ..., port: ...}` maps to filter
      results to specific targets
  """
  @spec describe_target_health(target_group_arn :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def describe_target_health(target_group_arn, opts \\ []) when is_binary(target_group_arn) do
    if sandbox?(opts) do
      sandbox_describe_target_health_response(target_group_arn, opts)
    else
      do_describe_target_health(target_group_arn, opts)
    end
  end

  defp do_describe_target_health(target_group_arn, opts) do
    params =
      flatten_query(%{
        "TargetGroupArn" => target_group_arn,
        "Targets" => opts[:targets]
      })

    "DescribeTargetHealth"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_describe_target_health/1)
  end

  @doc """
  Describes load balancers.

  Maps to AWS `DescribeLoadBalancers`. With no selector, describes every
  load balancer in the region.

  ## Options

    - `:names` - list of load balancer names; encoded as `Names.member.N`
    - `:load_balancer_arns` - list of load balancer ARNs
    - `:next_token` - pagination token (encoded as `Marker` on the wire)
    - `:page_size` - maximum results per page

  ## Pagination

  Returns one page plus `:next_token`; the caller decides whether to
  follow it.
  """
  @spec describe_load_balancers(opts :: keyword()) :: {:ok, map()} | {:error, term()}
  def describe_load_balancers(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_load_balancers_response(opts)
    else
      do_describe_load_balancers(opts)
    end
  end

  defp do_describe_load_balancers(opts) do
    params =
      flatten_query(%{
        "Names" => opts[:names],
        "LoadBalancerArns" => opts[:load_balancer_arns],
        "Marker" => opts[:next_token],
        "PageSize" => opts[:page_size]
      })

    "DescribeLoadBalancers"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_describe_load_balancers/1)
  end

  @doc """
  Describes every listener of a load balancer.

  Maps to AWS `DescribeListeners` with `LoadBalancerArn`. To describe
  specific listeners by their own ARNs, use `describe_listeners_by_arns/2`.

  ## Arguments

    - `load_balancer_arn` - describe every listener of this load balancer
    - `opts` - options below, plus shared credentials / region / endpoint

  ## Options

    - `:next_token` - pagination token (encoded as `Marker` on the wire)
    - `:page_size` - maximum results per page
  """
  @spec describe_listeners(load_balancer_arn :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def describe_listeners(load_balancer_arn, opts \\ []) when is_binary(load_balancer_arn) do
    if sandbox?(opts) do
      sandbox_describe_listeners_response(load_balancer_arn, opts)
    else
      do_describe_listeners(%{"LoadBalancerArn" => load_balancer_arn}, opts)
    end
  end

  @doc """
  Describes specific listeners by their ARNs.

  Maps to AWS `DescribeListeners` with `ListenerArns`. To describe every
  listener of a load balancer instead, use `describe_listeners/2`.

  ## Arguments

    - `listener_arns` - list of listener ARNs to describe
    - `opts` - options below, plus shared credentials / region / endpoint

  ## Options

    - `:next_token` - pagination token (encoded as `Marker` on the wire)
    - `:page_size` - maximum results per page
  """
  @spec describe_listeners_by_arns(listener_arns :: [String.t()], opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def describe_listeners_by_arns([_ | _] = listener_arns, opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_listeners_by_arns_response(listener_arns, opts)
    else
      do_describe_listeners(%{"ListenerArns" => listener_arns}, opts)
    end
  end

  defp do_describe_listeners(selector_params, opts) do
    params =
      selector_params
      |> Map.merge(%{
        "Marker" => opts[:next_token],
        "PageSize" => opts[:page_size]
      })
      |> flatten_query()

    "DescribeListeners"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_describe_listeners/1)
  end

  @doc """
  Describes every rule of a listener.

  Maps to AWS `DescribeRules` with `ListenerArn`. To describe specific
  rules by their own ARNs, use `describe_rules_by_arns/2`.

  Each rule carries its full `:conditions` and `:actions`, including the
  weighted target groups of a `forward` action's `ForwardConfig`, so
  callers can determine which target group currently receives traffic.

  ## Arguments

    - `listener_arn` - describe every rule of this listener
    - `opts` - options below, plus shared credentials / region / endpoint

  ## Options

    - `:next_token` - pagination token (encoded as `Marker` on the wire)
    - `:page_size` - maximum results per page
  """
  @spec describe_rules(listener_arn :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def describe_rules(listener_arn, opts \\ []) when is_binary(listener_arn) do
    if sandbox?(opts) do
      sandbox_describe_rules_response(listener_arn, opts)
    else
      do_describe_rules(%{"ListenerArn" => listener_arn}, opts)
    end
  end

  @doc """
  Describes specific rules by their ARNs.

  Maps to AWS `DescribeRules` with `RuleArns`. To describe every rule of a
  listener instead, use `describe_rules/2`. Rules carry the same
  `:conditions` and `:actions` detail described there.

  ## Arguments

    - `rule_arns` - list of rule ARNs to describe
    - `opts` - options below, plus shared credentials / region / endpoint

  ## Options

    - `:next_token` - pagination token (encoded as `Marker` on the wire)
    - `:page_size` - maximum results per page
  """
  @spec describe_rules_by_arns(rule_arns :: [String.t()], opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def describe_rules_by_arns([_ | _] = rule_arns, opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_rules_by_arns_response(rule_arns, opts)
    else
      do_describe_rules(%{"RuleArns" => rule_arns}, opts)
    end
  end

  defp do_describe_rules(selector_params, opts) do
    params =
      selector_params
      |> Map.merge(%{
        "Marker" => opts[:next_token],
        "PageSize" => opts[:page_size]
      })
      |> flatten_query()

    "DescribeRules"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_describe_rules/1)
  end

  @doc """
  Modifies a listener rule's actions and/or conditions.

  Maps to AWS `ModifyRule`. `:conditions` is optional, and when omitted
  the rule's existing conditions are left unchanged.

  `actions` and `:conditions` are nested structures encoded by
  `flatten_query/1`, so they are given as ordinary maps and lists. A
  weighted forward action — the shape a blue/green cutover uses, where
  the outgoing target group is kept at weight 0 so every propagation
  state routes somewhere live — looks like:

      AWS.ElasticLoadBalancingV2.modify_rule(rule_arn, [
        %{
          "Type" => "forward",
          "ForwardConfig" => %{
            "TargetGroups" => [
              %{"TargetGroupArn" => incoming, "Weight" => 100},
              %{"TargetGroupArn" => outgoing, "Weight" => 0}
            ]
          }
        }
      ])

  ## Arguments

    - `rule_arn` - the rule to modify
    - `actions` - list of action maps
    - `opts` - options below, plus shared credentials / region / endpoint

  ## Options

    - `:conditions` - list of condition maps
  """
  @spec modify_rule(rule_arn :: String.t(), actions :: [map()], opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def modify_rule(rule_arn, actions, opts \\ [])
      when is_binary(rule_arn) and is_list(actions) do
    if sandbox?(opts) do
      sandbox_modify_rule_response(rule_arn, actions, opts)
    else
      do_modify_rule(rule_arn, actions, opts)
    end
  end

  defp do_modify_rule(rule_arn, actions, opts) do
    params =
      flatten_query(%{
        "RuleArn" => rule_arn,
        "Actions" => actions,
        "Conditions" => opts[:conditions]
      })

    "ModifyRule"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_modify_rule/1)
  end

  # ---------------------------------------------------------------------------
  # Request building
  # ---------------------------------------------------------------------------

  @doc false
  def build_operation(action, params, opts) do
    opts = Keyword.put_new(opts, :region, @default_region)

    with {:ok, config} <- Client.resolve_config(:elastic_load_balancing_v2, opts, &default_host/1) do
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

      {:ok, apply_overrides(op, opts[:elastic_load_balancing_v2] || [])}
    end
  end

  defp default_host(region), do: "elasticloadbalancing.#{region}.amazonaws.com"

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
  # Generic AWS Query-protocol flattener (mirrors AWS.AutoScaling)
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

  defp sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    cfg = Config.sandbox()
    enabled = Keyword.get(sandbox_opts, :enabled, cfg[:enabled])

    enabled and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    @doc false
    defdelegate sandbox_disabled?, to: AWS.ElasticLoadBalancingV2.Sandbox

    @doc false
    defdelegate sandbox_describe_target_groups_response(opts),
      to: AWS.ElasticLoadBalancingV2.Sandbox,
      as: :describe_target_groups_response

    @doc false
    defdelegate sandbox_describe_target_health_response(target_group_arn, opts),
      to: AWS.ElasticLoadBalancingV2.Sandbox,
      as: :describe_target_health_response

    @doc false
    defdelegate sandbox_describe_load_balancers_response(opts),
      to: AWS.ElasticLoadBalancingV2.Sandbox,
      as: :describe_load_balancers_response

    @doc false
    defdelegate sandbox_describe_listeners_response(load_balancer_arn, opts),
      to: AWS.ElasticLoadBalancingV2.Sandbox,
      as: :describe_listeners_response

    @doc false
    defdelegate sandbox_describe_listeners_by_arns_response(listener_arns, opts),
      to: AWS.ElasticLoadBalancingV2.Sandbox,
      as: :describe_listeners_by_arns_response

    @doc false
    defdelegate sandbox_describe_rules_response(listener_arn, opts),
      to: AWS.ElasticLoadBalancingV2.Sandbox,
      as: :describe_rules_response

    @doc false
    defdelegate sandbox_describe_rules_by_arns_response(rule_arns, opts),
      to: AWS.ElasticLoadBalancingV2.Sandbox,
      as: :describe_rules_by_arns_response

    @doc false
    defdelegate sandbox_modify_rule_response(rule_arn, actions, opts),
      to: AWS.ElasticLoadBalancingV2.Sandbox,
      as: :modify_rule_response
  else
    @sandbox_unavailable "sandbox not available; add :sandbox_registry as a dep"

    defp sandbox_disabled?, do: false
    defp sandbox_describe_target_groups_response(_o), do: raise(@sandbox_unavailable)
    defp sandbox_describe_target_health_response(_a, _o), do: raise(@sandbox_unavailable)
    defp sandbox_describe_load_balancers_response(_o), do: raise(@sandbox_unavailable)
    defp sandbox_describe_listeners_response(_a, _o), do: raise(@sandbox_unavailable)
    defp sandbox_describe_listeners_by_arns_response(_a, _o), do: raise(@sandbox_unavailable)
    defp sandbox_describe_rules_response(_a, _o), do: raise(@sandbox_unavailable)
    defp sandbox_describe_rules_by_arns_response(_a, _o), do: raise(@sandbox_unavailable)
    defp sandbox_modify_rule_response(_r, _a, _o), do: raise(@sandbox_unavailable)
  end

  # ---------------------------------------------------------------------------
  # XML parsers
  # ---------------------------------------------------------------------------

  @doc false
  def parse_describe_target_groups(body) do
    result =
      xpath(body, ~x"//DescribeTargetGroupsResult"e,
        target_groups: [
          ~x"./TargetGroups/member"l,
          target_group_arn: ~x"./TargetGroupArn/text()"s,
          target_group_name: ~x"./TargetGroupName/text()"s
        ],
        next_token: ~x"./NextMarker/text()"s
      )

    %{
      target_groups: result.target_groups,
      next_token: nilify(result.next_token)
    }
  end

  @doc false
  def parse_describe_target_health(body) do
    result =
      xpath(body, ~x"//DescribeTargetHealthResult"e,
        target_health_descriptions: [
          ~x"./TargetHealthDescriptions/member"l,
          target_id: ~x"./Target/Id/text()"s,
          port: ~x"./Target/Port/text()"i,
          state: ~x"./TargetHealth/State/text()"s
        ]
      )

    %{target_health_descriptions: result.target_health_descriptions}
  end

  @doc false
  def parse_describe_load_balancers(body) do
    result =
      xpath(body, ~x"//DescribeLoadBalancersResult"e,
        load_balancers: [
          ~x"./LoadBalancers/member"l,
          load_balancer_arn: ~x"./LoadBalancerArn/text()"s,
          load_balancer_name: ~x"./LoadBalancerName/text()"s,
          dns_name: ~x"./DNSName/text()"s,
          scheme: ~x"./Scheme/text()"s,
          type: ~x"./Type/text()"s,
          vpc_id: ~x"./VpcId/text()"s,
          state: ~x"./State/Code/text()"s
        ],
        next_token: ~x"./NextMarker/text()"s
      )

    %{
      load_balancers: result.load_balancers,
      next_token: nilify(result.next_token)
    }
  end

  @doc false
  def parse_describe_listeners(body) do
    result =
      xpath(body, ~x"//DescribeListenersResult"e,
        listeners: [
          ~x"./Listeners/member"l,
          listener_arn: ~x"./ListenerArn/text()"s,
          load_balancer_arn: ~x"./LoadBalancerArn/text()"s,
          port: ~x"./Port/text()"oi,
          protocol: ~x"./Protocol/text()"s
        ],
        next_token: ~x"./NextMarker/text()"s
      )

    %{
      listeners: result.listeners,
      next_token: nilify(result.next_token)
    }
  end

  # Shared by DescribeRules and ModifyRule — both return <Rules><member>.
  # Actions keep their ForwardConfig target groups and weights, and
  # conditions keep their host-header values, so callers can see which
  # target group a rule currently favours.
  defp rule_fields do
    [
      rule_arn: ~x"./RuleArn/text()"s,
      priority: ~x"./Priority/text()"s,
      is_default: ~x"./IsDefault/text()"s,
      conditions: [
        ~x"./Conditions/member"l,
        field: ~x"./Field/text()"s,
        values: ~x"./Values/member/text()"sl,
        host_header_values: ~x"./HostHeaderConfig/Values/member/text()"sl
      ],
      actions: [
        ~x"./Actions/member"l,
        type: ~x"./Type/text()"s,
        order: ~x"./Order/text()"oi,
        target_group_arn: ~x"./TargetGroupArn/text()"s,
        target_groups: [
          ~x"./ForwardConfig/TargetGroups/member"l,
          target_group_arn: ~x"./TargetGroupArn/text()"s,
          weight: ~x"./Weight/text()"oi
        ]
      ]
    ]
  end

  @doc false
  def parse_describe_rules(body) do
    result =
      xpath(body, ~x"//DescribeRulesResult"e, [
        {:rules, [~x"./Rules/member"l | rule_fields()]},
        {:next_token, ~x"./NextMarker/text()"s}
      ])

    %{
      rules: normalize_rules(result.rules),
      next_token: nilify(result.next_token)
    }
  end

  @doc false
  def parse_modify_rule(body) do
    result =
      xpath(body, ~x"//ModifyRuleResult"e, [{:rules, [~x"./Rules/member"l | rule_fields()]}])

    %{rules: normalize_rules(result.rules)}
  end

  # XPath yields strings and empty strings; give callers real booleans
  # and nil-free absent values.
  defp normalize_rules(rules) do
    Enum.map(rules, fn rule ->
      rule
      |> Map.update!(:is_default, &boolish/1)
      |> Map.update!(:actions, fn actions ->
        Enum.map(actions, fn action ->
          Map.update!(action, :target_group_arn, &nilify/1)
        end)
      end)
    end)
  end

  defp boolish("true"), do: true
  defp boolish("false"), do: false
  defp boolish(""), do: nil
  defp boolish(other), do: other

  defp nilify(""), do: nil
  defp nilify(other), do: other
end
