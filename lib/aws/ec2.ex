defmodule AWS.EC2 do
  @moduledoc """
  `AWS.EC2` provides an API for Amazon Elastic Compute Cloud (EC2).

  This module calls the EC2 Query API directly via `AWS.HTTP` and
  `AWS.Signer` (through `AWS.Client`). The service model
  (`botocore/data/ec2/2016-11-15/service-2.json`) declares
  `metadata.protocols = ["ec2", "query"]`; both are form-urlencoded
  request / XML response, handled here with `SweetXml`.

  EC2 is regional. Requests are sent to `ec2.<region>.amazonaws.com`
  with SigV4 signing under the same region.

  The scope of this module is deliberately narrow: security groups,
  VPC/subnet discovery, and tagging — the operations needed by the
  callers of this library. Each public function mirrors the wrapper
  pattern used throughout `AWS.*` (inline sandbox branch + `do_*`
  helper + typed response map).

  ## Shared Options

  Same shape as the other service modules (`AWS.IAM`, `AWS.Organizations`,
  etc.): flat top-level credential keys (`:access_key_id`,
  `:secret_access_key`, `:security_token`, `:region`) plus:

    - `:ec2` - Keyword overrides for endpoint (`:scheme`, `:host`, `:port`).
    - `:sandbox` - Sandbox configuration as in other services.

  ## Sandbox

  Set `sandbox: [enabled: true]` and register responses
  via `AWS.EC2.Sandbox`.
  """

  import SweetXml, only: [xpath: 2, xpath: 3, sigil_x: 2]
  alias AWS.{Client, Config}
  alias AWS.EC2.Operation

  @service "ec2"
  @content_type "application/x-www-form-urlencoded"
  @api_version "2016-11-15"
  @default_region "us-east-1"

  @override_keys [:headers, :body, :http, :url]

  # ---------------------------------------------------------------------------
  # Security Groups
  # ---------------------------------------------------------------------------

  @doc """
  Creates a VPC security group.

  ## Arguments

    * `name` - The security group name.
    * `description` - Group description (required by AWS).
    * `vpc_id` - VPC ID in which to create the group.
    * `opts` - Shared options.
  """
  @spec create_security_group(
          name :: String.t(),
          description :: String.t(),
          vpc_id :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{group_id: String.t()}} | {:error, term()}
  def create_security_group(name, description, vpc_id, opts \\ []) do
    if sandbox?(opts) do
      sandbox_create_security_group_response(name, opts)
    else
      do_create_security_group(name, description, vpc_id, opts)
    end
  end

  defp do_create_security_group(name, description, vpc_id, opts) do
    params = %{
      "GroupName" => name,
      "GroupDescription" => description,
      "VpcId" => vpc_id
    }

    "CreateSecurityGroup"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      {:ok, %{group_id: xpath(body, ~x"//groupId/text()"s)}}
    end)
  end

  @doc """
  Describes one or more security groups.

  ## Options

    * `:group_ids` - List of security group IDs.
    * `:group_names` - List of security group names (EC2-Classic / default VPC only).
    * `:filters` - List of `%{name: String.t(), values: [String.t()]}` filters.
  """
  @spec describe_security_groups(opts :: keyword()) ::
          {:ok, %{security_groups: list(map())}} | {:error, term()}
  def describe_security_groups(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_security_groups_response(opts)
    else
      do_describe_security_groups(opts)
    end
  end

  defp do_describe_security_groups(opts) do
    params =
      %{}
      |> put_member_list("GroupId", opts[:group_ids] || [])
      |> put_member_list("GroupName", opts[:group_names] || [])
      |> put_filters(opts[:filters] || [])

    "DescribeSecurityGroups"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      groups =
        xpath(body, ~x"//securityGroupInfo/item"l,
          group_id: ~x"./groupId/text()"s,
          group_name: ~x"./groupName/text()"s,
          description: ~x"./groupDescription/text()"s,
          vpc_id: ~x"./vpcId/text()"s,
          owner_id: ~x"./ownerId/text()"s
        )

      {:ok, %{security_groups: groups}}
    end)
  end

  @doc """
  Deletes a security group.
  """
  @spec delete_security_group(group_id :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_security_group(group_id, opts \\ []) do
    if sandbox?(opts) do
      sandbox_delete_security_group_response(group_id, opts)
    else
      do_delete_security_group(group_id, opts)
    end
  end

  defp do_delete_security_group(group_id, opts) do
    "DeleteSecurityGroup"
    |> perform(%{"GroupId" => group_id}, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Adds ingress rules to a security group.

  `ip_permissions` is a list of maps with keys `:protocol`, `:from_port`,
  `:to_port`, and either `:ip_ranges` (list of `%{cidr_ip:, description:}`)
  or `:user_id_group_pairs` (list of `%{group_id:, description:}`).
  """
  @spec authorize_security_group_ingress(
          group_id :: String.t(),
          ip_permissions :: list(map()),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def authorize_security_group_ingress(group_id, ip_permissions, opts \\ []) do
    if sandbox?(opts) do
      sandbox_authorize_security_group_ingress_response(group_id, opts)
    else
      do_sg_rule_op("AuthorizeSecurityGroupIngress", group_id, ip_permissions, opts)
    end
  end

  @doc """
  Revokes ingress rules from a security group.
  """
  @spec revoke_security_group_ingress(
          group_id :: String.t(),
          ip_permissions :: list(map()),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def revoke_security_group_ingress(group_id, ip_permissions, opts \\ []) do
    if sandbox?(opts) do
      sandbox_revoke_security_group_ingress_response(group_id, opts)
    else
      do_sg_rule_op("RevokeSecurityGroupIngress", group_id, ip_permissions, opts)
    end
  end

  @doc """
  Adds egress rules to a security group.
  """
  @spec authorize_security_group_egress(
          group_id :: String.t(),
          ip_permissions :: list(map()),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def authorize_security_group_egress(group_id, ip_permissions, opts \\ []) do
    if sandbox?(opts) do
      sandbox_authorize_security_group_egress_response(group_id, opts)
    else
      do_sg_rule_op("AuthorizeSecurityGroupEgress", group_id, ip_permissions, opts)
    end
  end

  @doc """
  Revokes egress rules from a security group.
  """
  @spec revoke_security_group_egress(
          group_id :: String.t(),
          ip_permissions :: list(map()),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def revoke_security_group_egress(group_id, ip_permissions, opts \\ []) do
    if sandbox?(opts) do
      sandbox_revoke_security_group_egress_response(group_id, opts)
    else
      do_sg_rule_op("RevokeSecurityGroupEgress", group_id, ip_permissions, opts)
    end
  end

  defp do_sg_rule_op(action, group_id, ip_permissions, opts) do
    params =
      %{"GroupId" => group_id}
      |> put_ip_permissions(ip_permissions)

    action
    |> perform(params, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  # ---------------------------------------------------------------------------
  # VPCs / Subnets
  # ---------------------------------------------------------------------------

  @doc """
  Describes one or more VPCs.

  ## Options

    * `:vpc_ids` - List of VPC IDs.
    * `:filters` - List of `%{name:, values:}` filters.
  """
  @spec describe_vpcs(opts :: keyword()) ::
          {:ok, %{vpcs: list(map())}} | {:error, term()}
  def describe_vpcs(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_vpcs_response(opts)
    else
      do_describe_vpcs(opts)
    end
  end

  defp do_describe_vpcs(opts) do
    params =
      %{}
      |> put_member_list("VpcId", opts[:vpc_ids] || [])
      |> put_filters(opts[:filters] || [])

    "DescribeVpcs"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      vpcs =
        xpath(body, ~x"//vpcSet/item"l,
          vpc_id: ~x"./vpcId/text()"s,
          cidr_block: ~x"./cidrBlock/text()"s,
          state: ~x"./state/text()"s,
          is_default: ~x"./isDefault/text()"s
        )

      {:ok, %{vpcs: Enum.map(vpcs, &coerce_is_default/1)}}
    end)
  end

  defp coerce_is_default(%{is_default: value} = vpc) do
    %{vpc | is_default: value === "true"}
  end

  @doc """
  Describes one or more subnets.

  ## Options

    * `:subnet_ids` - List of subnet IDs.
    * `:filters` - List of `%{name:, values:}` filters.
  """
  @spec describe_subnets(opts :: keyword()) ::
          {:ok, %{subnets: list(map())}} | {:error, term()}
  def describe_subnets(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_subnets_response(opts)
    else
      do_describe_subnets(opts)
    end
  end

  defp do_describe_subnets(opts) do
    params =
      %{}
      |> put_member_list("SubnetId", opts[:subnet_ids] || [])
      |> put_filters(opts[:filters] || [])

    "DescribeSubnets"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      subnets =
        xpath(body, ~x"//subnetSet/item"l,
          subnet_id: ~x"./subnetId/text()"s,
          vpc_id: ~x"./vpcId/text()"s,
          cidr_block: ~x"./cidrBlock/text()"s,
          availability_zone: ~x"./availabilityZone/text()"s,
          state: ~x"./state/text()"s
        )

      {:ok, %{subnets: subnets}}
    end)
  end

  # ---------------------------------------------------------------------------
  # Instances
  # ---------------------------------------------------------------------------

  @doc """
  Describes one or more instances, grouped by reservation.

  Returns `%{reservations: [...]}` where each reservation contains a list of
  `:instances`. Each instance includes its `:tags` and `:security_groups`
  (parsed from the instance-level `groupSet`).

  ## Options

    * `:instance_ids` - List of instance IDs to describe.
    * `:filters` - List of `%{name:, values:}` filters.
  """
  @spec describe_instances(opts :: keyword()) ::
          {:ok, %{reservations: list(map())}} | {:error, term()}
  def describe_instances(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_instances_response(opts)
    else
      do_describe_instances(opts)
    end
  end

  defp do_describe_instances(opts) do
    params =
      %{}
      |> put_member_list("InstanceId", opts[:instance_ids] || [])
      |> put_filters(opts[:filters] || [])

    "DescribeInstances"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      reservations =
        xpath(body, ~x"//reservationSet/item"l,
          reservation_id: ~x"./reservationId/text()"s,
          owner_id: ~x"./ownerId/text()"s,
          instances: [
            ~x"./instancesSet/item"l,
            instance_id: ~x"./instanceId/text()"s,
            image_id: ~x"./imageId/text()"s,
            instance_type: ~x"./instanceType/text()"s,
            state: ~x"./instanceState/name/text()"s,
            private_ip_address: ~x"./privateIpAddress/text()"s,
            public_ip_address: ~x"./ipAddress/text()"s,
            subnet_id: ~x"./subnetId/text()"s,
            vpc_id: ~x"./vpcId/text()"s,
            availability_zone: ~x"./placement/availabilityZone/text()"s,
            launch_time: ~x"./launchTime/text()"s,
            tags: [
              ~x"./tagSet/item"l,
              key: ~x"./key/text()"s,
              value: ~x"./value/text()"s
            ],
            security_groups: [
              ~x"./groupSet/item"l,
              group_id: ~x"./groupId/text()"s,
              group_name: ~x"./groupName/text()"s
            ]
          ]
        )

      {:ok, %{reservations: reservations}}
    end)
  end

  # ---------------------------------------------------------------------------
  # Tags
  # ---------------------------------------------------------------------------

  @doc """
  Adds or overwrites tags on one or more EC2 resources.

  `tags` is a list of `%{key:, value:}` maps or `{key, value}` tuples.
  """
  @spec create_tags(
          resource_ids :: list(String.t()),
          tags :: list(map() | {String.t(), String.t()}),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def create_tags(resource_ids, tags, opts \\ []) do
    if sandbox?(opts) do
      sandbox_create_tags_response(resource_ids, opts)
    else
      do_create_tags(resource_ids, tags, opts)
    end
  end

  defp do_create_tags(resource_ids, tags, opts) do
    params =
      %{}
      |> put_member_list("ResourceId", resource_ids)
      |> put_tags("Tag", tags)

    "CreateTags"
    |> perform(params, opts)
    |> deserialize_response(opts, fn _ -> {:ok, %{}} end)
  end

  @doc """
  Describes the specified tags for the given resources.

  Returns `%{tags: [...]}`, where each tag is
  `%{resource_id:, resource_type:, key:, value:}`.

  ## Options

    * `:filters` - List of `%{name:, values:}` filters. Common filter names:
      `"key"`, `"value"`, `"resource-id"`, `"resource-type"`.
  """
  @spec describe_tags(opts :: keyword()) ::
          {:ok, %{tags: list(map())}} | {:error, term()}
  def describe_tags(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_tags_response(opts)
    else
      do_describe_tags(opts)
    end
  end

  defp do_describe_tags(opts) do
    params = put_filters(%{}, opts[:filters] || [])

    "DescribeTags"
    |> perform(params, opts)
    |> deserialize_response(opts, fn body ->
      tags =
        xpath(body, ~x"//tagSet/item"l,
          resource_id: ~x"./resourceId/text()"s,
          resource_type: ~x"./resourceType/text()"s,
          key: ~x"./key/text()"s,
          value: ~x"./value/text()"s
        )

      {:ok, %{tags: tags}}
    end)
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
    defdelegate sandbox_disabled?, to: AWS.EC2.Sandbox, as: :sandbox_disabled?

    @doc false
    defdelegate sandbox_create_security_group_response(name, opts),
      to: AWS.EC2.Sandbox,
      as: :create_security_group_response

    @doc false
    defdelegate sandbox_describe_security_groups_response(opts),
      to: AWS.EC2.Sandbox,
      as: :describe_security_groups_response

    @doc false
    defdelegate sandbox_delete_security_group_response(group_id, opts),
      to: AWS.EC2.Sandbox,
      as: :delete_security_group_response

    @doc false
    defdelegate sandbox_authorize_security_group_ingress_response(group_id, opts),
      to: AWS.EC2.Sandbox,
      as: :authorize_security_group_ingress_response

    @doc false
    defdelegate sandbox_revoke_security_group_ingress_response(group_id, opts),
      to: AWS.EC2.Sandbox,
      as: :revoke_security_group_ingress_response

    @doc false
    defdelegate sandbox_authorize_security_group_egress_response(group_id, opts),
      to: AWS.EC2.Sandbox,
      as: :authorize_security_group_egress_response

    @doc false
    defdelegate sandbox_revoke_security_group_egress_response(group_id, opts),
      to: AWS.EC2.Sandbox,
      as: :revoke_security_group_egress_response

    @doc false
    defdelegate sandbox_describe_vpcs_response(opts),
      to: AWS.EC2.Sandbox,
      as: :describe_vpcs_response

    @doc false
    defdelegate sandbox_describe_subnets_response(opts),
      to: AWS.EC2.Sandbox,
      as: :describe_subnets_response

    @doc false
    defdelegate sandbox_create_tags_response(resource_ids, opts),
      to: AWS.EC2.Sandbox,
      as: :create_tags_response

    @doc false
    defdelegate sandbox_describe_tags_response(opts),
      to: AWS.EC2.Sandbox,
      as: :describe_tags_response

    @doc false
    defdelegate sandbox_describe_instances_response(opts),
      to: AWS.EC2.Sandbox,
      as: :describe_instances_response
  else
    defp sandbox_disabled?, do: true

    defp sandbox_create_security_group_response(_, _), do: raise("sandbox not available")
    defp sandbox_describe_security_groups_response(_), do: raise("sandbox not available")
    defp sandbox_delete_security_group_response(_, _), do: raise("sandbox not available")

    defp sandbox_authorize_security_group_ingress_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_revoke_security_group_ingress_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_authorize_security_group_egress_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_revoke_security_group_egress_response(_, _),
      do: raise("sandbox not available")

    defp sandbox_describe_vpcs_response(_), do: raise("sandbox not available")
    defp sandbox_describe_subnets_response(_), do: raise("sandbox not available")
    defp sandbox_create_tags_response(_, _), do: raise("sandbox not available")
    defp sandbox_describe_tags_response(_), do: raise("sandbox not available")
    defp sandbox_describe_instances_response(_), do: raise("sandbox not available")
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @doc false
  def build_operation(action, params, opts) do
    opts = Keyword.put_new(opts, :region, @default_region)

    with {:ok, config} <- Client.resolve_config(:ec2, opts, &default_host/1) do
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

      {:ok, apply_overrides(op, opts[:ec2] || [])}
    end
  end

  defp default_host(region), do: "ec2.#{region}.amazonaws.com"

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

  defp deserialize_response({:ok, response}, _opts, func) do
    case func.(response) do
      {:ok, _} = ok -> ok
      {:error, _} = err -> err
      result -> {:ok, result}
    end
  end

  defp deserialize_response({:error, reason}, _opts, _func) do
    {:error, ErrorMessage.internal_server_error("internal server error", %{reason: reason})}
  end

  defp put_member_list(map, _prefix, []), do: map

  defp put_member_list(map, prefix, values) when is_list(values) do
    values
    |> Enum.with_index(1)
    |> Enum.reduce(map, fn {value, idx}, acc ->
      Map.put(acc, "#{prefix}.#{idx}", value)
    end)
  end

  defp put_filters(map, []), do: map

  defp put_filters(map, filters) when is_list(filters) do
    filters
    |> Enum.with_index(1)
    |> Enum.reduce(map, fn {filter, idx}, acc ->
      name = filter[:name] || filter["Name"]
      values = filter[:values] || filter["Values"] || []

      acc = Map.put(acc, "Filter.#{idx}.Name", name)

      values
      |> Enum.with_index(1)
      |> Enum.reduce(acc, fn {value, vidx}, a ->
        Map.put(a, "Filter.#{idx}.Value.#{vidx}", value)
      end)
    end)
  end

  defp put_tags(map, prefix, tags) do
    tags
    |> Enum.with_index(1)
    |> Enum.reduce(map, fn {tag, idx}, acc ->
      {key, value} = normalize_tag(tag)

      acc
      |> Map.put("#{prefix}.#{idx}.Key", key)
      |> Map.put("#{prefix}.#{idx}.Value", value)
    end)
  end

  defp normalize_tag({key, value}), do: {to_string(key), to_string(value)}
  defp normalize_tag(%{key: k, value: v}), do: {to_string(k), to_string(v)}
  defp normalize_tag(%{"Key" => k, "Value" => v}), do: {to_string(k), to_string(v)}

  defp put_ip_permissions(map, permissions) do
    permissions
    |> Enum.with_index(1)
    |> Enum.reduce(map, fn {perm, idx}, acc ->
      base = "IpPermissions.#{idx}"

      acc
      |> maybe_put("#{base}.IpProtocol", perm[:protocol])
      |> maybe_put("#{base}.FromPort", perm[:from_port])
      |> maybe_put("#{base}.ToPort", perm[:to_port])
      |> put_ip_ranges("#{base}.IpRanges", perm[:ip_ranges] || [])
      |> put_user_id_group_pairs(
        "#{base}.Groups",
        perm[:user_id_group_pairs] || []
      )
    end)
  end

  defp put_ip_ranges(map, prefix, ranges) do
    ranges
    |> Enum.with_index(1)
    |> Enum.reduce(map, fn {range, idx}, acc ->
      acc
      |> maybe_put("#{prefix}.#{idx}.CidrIp", range[:cidr_ip])
      |> maybe_put("#{prefix}.#{idx}.Description", range[:description])
    end)
  end

  defp put_user_id_group_pairs(map, prefix, pairs) do
    pairs
    |> Enum.with_index(1)
    |> Enum.reduce(map, fn {pair, idx}, acc ->
      acc
      |> maybe_put("#{prefix}.#{idx}.GroupId", pair[:group_id])
      |> maybe_put("#{prefix}.#{idx}.Description", pair[:description])
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, to_string(value))
end
