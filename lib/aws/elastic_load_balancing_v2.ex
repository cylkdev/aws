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

  Only the two read-only operations needed by current callers are
  implemented: `describe_target_groups/1` and `describe_target_health/1`.

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
  @spec describe_target_groups(keyword) :: {:ok, map} | {:error, term}
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

  Maps to AWS `DescribeTargetHealth`. `:target_group_arn` is required.

  ## Options

    - `:target_group_arn` - target group ARN (required)
    - `:targets` - list of `%{id: ..., port: ...}` maps to filter
      results to specific targets
  """
  @spec describe_target_health(keyword) :: {:ok, map} | {:error, term}
  def describe_target_health(opts \\ []) do
    require_opts!(opts, [:target_group_arn])

    if sandbox?(opts) do
      sandbox_describe_target_health_response(opts)
    else
      do_describe_target_health(opts)
    end
  end

  defp do_describe_target_health(opts) do
    params =
      flatten_query(%{
        "TargetGroupArn" => opts[:target_group_arn],
        "Targets" => opts[:targets]
      })

    "DescribeTargetHealth"
    |> perform(params, opts)
    |> deserialize_response(opts, &parse_describe_target_health/1)
  end

  defp require_opts!(opts, keys) do
    Enum.each(keys, fn key ->
      if is_nil(opts[key]) do
        raise ArgumentError, "missing required option #{inspect(key)}"
      end
    end)
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
    defdelegate sandbox_describe_target_health_response(opts),
      to: AWS.ElasticLoadBalancingV2.Sandbox,
      as: :describe_target_health_response
  else
    @sandbox_unavailable "sandbox not available; add :sandbox_registry as a dep"

    defp sandbox_disabled?, do: false
    defp sandbox_describe_target_groups_response(_o), do: raise(@sandbox_unavailable)
    defp sandbox_describe_target_health_response(_o), do: raise(@sandbox_unavailable)
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

  defp nilify(""), do: nil
  defp nilify(other), do: other
end
