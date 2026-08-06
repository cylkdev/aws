defmodule AwsSdk.EC2 do
  @moduledoc """
  `AwsSdk.EC2` provides an API for Amazon Elastic Compute Cloud (EC2).

  This module calls the EC2 Query API directly via `AwsSdk.HTTP` and
  `AwsSdk.Signer` (through `AwsSdk.Client`). The service model
  (`botocore/data/ec2/2016-11-15/service-2.json`) declares
  `metadata.protocols = ["ec2", "query"]`; both are form-urlencoded
  request / XML response, handled here with `SweetXml`.

  EC2 is regional. Requests are sent to `ec2.<region>.amazonaws.com`
  with SigV4 signing under the same region.

  The scope of this module is deliberately narrow: security groups,
  VPC/subnet discovery, instance and tag lookup, launch template reads,
  and AMI/snapshot lifecycle — the operations needed by the callers of
  this library. Instances are described and terminated but never launched
  here; launch templates are read but never created or modified; the
  image operations exist to retire AMIs a build pipeline has
  superseded. Each public function mirrors the wrapper
  pattern used throughout `AwsSdk.*` (inline sandbox branch + `do_*`
  helper + typed response map).

  ## Shared Options

  Same shape as the other service modules (`AwsSdk.IAM`, `AwsSdk.Organizations`,
  etc.): flat top-level credential keys (`:access_key_id`,
  `:secret_access_key`, `:security_token`, `:region`) plus:

    - `:ec2` - Keyword overrides for endpoint (`:scheme`, `:host`, `:port`).
    - `:sandbox` - Sandbox configuration as in other services.

  ## Sandbox

  Set `sandbox: [enabled: true]` and register responses
  via `AwsSdk.EC2.Sandbox`.
  """

  import SweetXml, only: [xpath: 2, xpath: 3, sigil_x: 2]

  alias AwsSdk.Client
  alias AwsSdk.Operation

  @service "ec2"
  @content_type "application/x-www-form-urlencoded"
  @api_version "2016-11-15"
  @default_region "us-east-1"

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

  Returns the `CreateSecurityGroup` result as AWS models it: `:group_id` plus
  the `:tag_set` applied at creation.

  ## Examples

      AwsSdk.EC2.create_security_group("WebServers", "Web servers", "vpc-1a2b3c4d")
      #=> {:ok, %{group_id: "sg-1a2b3c4d", tag_set: []}}
  """
  @spec create_security_group(
          name :: String.t(),
          description :: String.t(),
          vpc_id :: String.t(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
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

    with {:ok, op} <- build_operation("CreateSecurityGroup", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok,
       xpath(
         body,
         ~x"//CreateSecurityGroupResponse"e,
         group_id: ~x"./groupId/text()"s,
         tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
       )}
    end
  end

  @doc """
  Describes one or more security groups.

  ## Options

    * `:group_ids` - List of security group IDs.
    * `:group_names` - List of security group names (EC2-Classic / default VPC only).
    * `:filters` - List of `%{name: String.t(), values: [String.t()]}` filters.

  ## Examples

      AwsSdk.EC2.describe_security_groups(group_ids: ["sg-1a2b3c4d"])
      #=> {:ok,
      #=>  %{
      #=>    security_group_info: [
      #=>      %{
      #=>        group_id: "sg-1a2b3c4d",
      #=>        group_name: "WebServers",
      #=>        group_description: "Web servers",
      #=>        vpc_id: "vpc-1a2b3c4d",
      #=>        owner_id: "123456789012",
      #=>        security_group_arn: "",
      #=>        ip_permissions: [
      #=>          %{
      #=>            ip_protocol: "tcp",
      #=>            from_port: 443,
      #=>            to_port: 443,
      #=>            ip_ranges: [%{cidr_ip: "0.0.0.0/0", description: ""}],
      #=>            ipv6_ranges: [],
      #=>            prefix_list_ids: [],
      #=>            groups: []
      #=>          }
      #=>        ],
      #=>        ip_permissions_egress: [],
      #=>        tag_set: [%{key: "Name", value: "web"}]
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}

  `:from_port` / `:to_port` are `nil` when `ip_protocol` is `"-1"` (all
  protocols) -- AWS omits the elements rather than sending -1.
  """
  @spec describe_security_groups(opts :: keyword()) ::
          {:ok, %{security_group_info: list(map()), next_token: String.t() | nil}}
          | {:error, term()}
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

    with {:ok, op} <- build_operation("DescribeSecurityGroups", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      groups =
        xpath(body, ~x"//securityGroupInfo/item"l,
          group_id: ~x"./groupId/text()"s,
          group_name: ~x"./groupName/text()"s,
          group_description: ~x"./groupDescription/text()"s,
          vpc_id: ~x"./vpcId/text()"s,
          owner_id: ~x"./ownerId/text()"s,
          security_group_arn: ~x"./securityGroupArn/text()"os,
          tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s],
          ip_permissions: [
            ~x"./ipPermissions/item"l,
            ip_protocol: ~x"./ipProtocol/text()"s,
            # Structurally ABSENT (no element) whenever ipProtocol is "-1".
            # A present element containing -1 means "all ICMP types" and is a
            # different case entirely.
            from_port: ~x"./fromPort/text()"oi,
            to_port: ~x"./toPort/text()"oi,
            ip_ranges: [
              ~x"./ipRanges/item"l,
              cidr_ip: ~x"./cidrIp/text()"s,
              description: ~x"./description/text()"os
            ],
            ipv6_ranges: [
              ~x"./ipv6Ranges/item"l,
              cidr_ipv6: ~x"./cidrIpv6/text()"s,
              description: ~x"./description/text()"os
            ],
            prefix_list_ids: [
              ~x"./prefixListIds/item"l,
              prefix_list_id: ~x"./prefixListId/text()"s,
              description: ~x"./description/text()"os
            ],
            groups: [
              ~x"./groups/item"l,
              group_id: ~x"./groupId/text()"os,
              group_name: ~x"./groupName/text()"os,
              user_id: ~x"./userId/text()"os,
              vpc_id: ~x"./vpcId/text()"os,
              vpc_peering_connection_id: ~x"./vpcPeeringConnectionId/text()"os,
              peering_status: ~x"./peeringStatus/text()"os,
              description: ~x"./description/text()"os
            ]
          ],
          ip_permissions_egress: [
            ~x"./ipPermissionsEgress/item"l,
            ip_protocol: ~x"./ipProtocol/text()"s,
            # Structurally ABSENT (no element) whenever ipProtocol is "-1".
            # A present element containing -1 means "all ICMP types" and is a
            # different case entirely.
            from_port: ~x"./fromPort/text()"oi,
            to_port: ~x"./toPort/text()"oi,
            ip_ranges: [
              ~x"./ipRanges/item"l,
              cidr_ip: ~x"./cidrIp/text()"s,
              description: ~x"./description/text()"os
            ],
            ipv6_ranges: [
              ~x"./ipv6Ranges/item"l,
              cidr_ipv6: ~x"./cidrIpv6/text()"s,
              description: ~x"./description/text()"os
            ],
            prefix_list_ids: [
              ~x"./prefixListIds/item"l,
              prefix_list_id: ~x"./prefixListId/text()"s,
              description: ~x"./description/text()"os
            ],
            groups: [
              ~x"./groups/item"l,
              group_id: ~x"./groupId/text()"os,
              group_name: ~x"./groupName/text()"os,
              user_id: ~x"./userId/text()"os,
              vpc_id: ~x"./vpcId/text()"os,
              vpc_peering_connection_id: ~x"./vpcPeeringConnectionId/text()"os,
              peering_status: ~x"./peeringStatus/text()"os,
              description: ~x"./description/text()"os
            ]
          ]
        )

      {:ok,
       %{
         security_group_info: groups,
         next_token: xpath(body, ~x"//DescribeSecurityGroupsResponse/nextToken/text()"os)
       }}
    end
  end

  @doc """
  Deletes a security group.

  ## Examples

      AwsSdk.EC2.delete_security_group(group_id: "sg-1a2b3c4d")
      #=> {:ok, %{return: true}}

      # GroupId and GroupName are alternatives; supply one.
      AwsSdk.EC2.delete_security_group(group_name: "WebServers")
      #=> {:ok, %{return: true}}
  """
  @spec delete_security_group(opts :: keyword()) :: {:ok, map()} | {:error, term()}
  def delete_security_group(opts \\ []) do
    if sandbox?(opts) do
      sandbox_delete_security_group_response(opts)
    else
      do_delete_security_group(opts)
    end
  end

  defp do_delete_security_group(opts) do
    # AWS documents both GroupId and GroupName as optional -- you supply one.
    # Forcing GroupId made deletion by name unreachable.
    params =
      %{}
      |> maybe_put("GroupId", opts[:group_id])
      |> maybe_put("GroupName", opts[:group_name])

    with {:ok, op} <- build_operation("DeleteSecurityGroup", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_return(body)}
    end
  end

  @doc """
  Adds ingress rules to a security group.

  `ip_permissions` is a list of maps with keys `:protocol`, `:from_port`,
  `:to_port`, and either `:ip_ranges` (list of `%{cidr_ip:, description:}`)
  or `:user_id_group_pairs` (list of `%{group_id:, description:}`).

  ## Examples

      AwsSdk.EC2.authorize_security_group_ingress("sg-1a2b3c4d", [
        %{
          protocol: "tcp",
          from_port: 443,
          to_port: 443,
          ip_ranges: [%{cidr_ip: "0.0.0.0/0", description: "https"}]
        }
      ])
      #=> {:ok,
      #=>  %{
      #=>    return: true,
      #=>    security_group_rule_set: [
      #=>      %{
      #=>        security_group_rule_id: "sgr-0a1b2c3d",
      #=>        group_id: "sg-1a2b3c4d",
      #=>        group_owner_id: "123456789012",
      #=>        is_egress: "false",
      #=>        ip_protocol: "tcp",
      #=>        from_port: 443,
      #=>        to_port: 443,
      #=>        cidr_ipv4: "0.0.0.0/0",
      #=>        cidr_ipv6: "",
      #=>        prefix_list_id: "",
      #=>        referenced_group_info: nil,
      #=>        description: "https",
      #=>        tag_set: [],
      #=>        security_group_rule_arn: ""
      #=>      }
      #=>    ]
      #=>  }}
  """
  @spec authorize_security_group_ingress(
          group_id :: String.t(),
          ip_permissions :: list(map()),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def authorize_security_group_ingress(group_id, ip_permissions, opts \\ []) do
    if sandbox?(opts) do
      sandbox_authorize_security_group_ingress_response(group_id, opts)
    else
      do_sg_rule_op("AuthorizeSecurityGroupIngress", group_id, ip_permissions, opts)
    end
  end

  @doc """
  Revokes ingress rules from a security group.

  ## Examples

      AwsSdk.EC2.revoke_security_group_ingress("sg-1a2b3c4d", [
        %{protocol: "tcp", from_port: 443, to_port: 443,
          ip_ranges: [%{cidr_ip: "0.0.0.0/0"}]}
      ])
      #=> {:ok,
      #=>  %{
      #=>    return: true,
      #=>    unknown_ip_permission_set: [],
      #=>    revoked_security_group_rule_set: [
      #=>      %{security_group_rule_id: "sgr-0a1b2c3d", ip_protocol: "tcp"}
      #=>    ]
      #=>  }}

  Rules AWS could not find come back in `:unknown_ip_permission_set` rather
  than as an error.
  """
  @spec revoke_security_group_ingress(
          group_id :: String.t(),
          ip_permissions :: list(map()),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def revoke_security_group_ingress(group_id, ip_permissions, opts \\ []) do
    if sandbox?(opts) do
      sandbox_revoke_security_group_ingress_response(group_id, opts)
    else
      do_sg_rule_op("RevokeSecurityGroupIngress", group_id, ip_permissions, opts)
    end
  end

  @doc """
  Adds egress rules to a security group.

  ## Examples

      AwsSdk.EC2.authorize_security_group_egress("sg-1a2b3c4d", [
        %{protocol: "tcp", from_port: 5432, to_port: 5432,
          user_id_group_pairs: [%{group_id: "sg-9z8y7x6w"}]}
      ])
      #=> {:ok,
      #=>  %{
      #=>    return: true,
      #=>    security_group_rule_set: [
      #=>      %{
      #=>        security_group_rule_id: "sgr-1b2c3d4e",
      #=>        is_egress: "true",
      #=>        ip_protocol: "tcp",
      #=>        from_port: 5432,
      #=>        to_port: 5432,
      #=>        referenced_group_info: %{group_id: "sg-9z8y7x6w"}
      #=>      }
      #=>    ]
      #=>  }}
  """
  @spec authorize_security_group_egress(
          group_id :: String.t(),
          ip_permissions :: list(map()),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def authorize_security_group_egress(group_id, ip_permissions, opts \\ []) do
    if sandbox?(opts) do
      sandbox_authorize_security_group_egress_response(group_id, opts)
    else
      do_sg_rule_op("AuthorizeSecurityGroupEgress", group_id, ip_permissions, opts)
    end
  end

  @doc """
  Revokes egress rules from a security group.

  ## Examples

      AwsSdk.EC2.revoke_security_group_egress("sg-1a2b3c4d", [
        %{protocol: "-1", ip_ranges: [%{cidr_ip: "0.0.0.0/0"}]}
      ])
      #=> {:ok,
      #=>  %{
      #=>    return: true,
      #=>    unknown_ip_permission_set: [],
      #=>    revoked_security_group_rule_set: [%{security_group_rule_id: "sgr-2c3d4e5f"}]
      #=>  }}
  """
  @spec revoke_security_group_egress(
          group_id :: String.t(),
          ip_permissions :: list(map()),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
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

    with {:ok, op} <- build_operation(action, params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_sg_rule_result(action, body)}
    end
  end

  # Authorize and Revoke return different members, so they are parsed
  # separately rather than as a union -- a shared parser would have to invent
  # keys for whichever action did not send them.
  defp parse_sg_rule_result("Authorize" <> _, body) do
    body
    |> parse_return()
    |> Map.put(:security_group_rule_set, parse_security_group_rule_set(body))
  end

  defp parse_sg_rule_result("Revoke" <> _, body) do
    Map.merge(parse_return(body), %{
      unknown_ip_permission_set: parse_ip_permission_set(body),
      revoked_security_group_rule_set: parse_security_group_rule_set(body)
    })
  end

  defp parse_security_group_rule_set(body) do
    xpath(body, ~x"//securityGroupRuleSet/item"l,
      security_group_rule_id: ~x"./securityGroupRuleId/text()"os,
      group_id: ~x"./groupId/text()"os,
      group_owner_id: ~x"./groupOwnerId/text()"os,
      is_egress: ~x"./isEgress/text()"os,
      ip_protocol: ~x"./ipProtocol/text()"os,
      from_port: ~x"./fromPort/text()"oi,
      to_port: ~x"./toPort/text()"oi,
      cidr_ipv4: ~x"./cidrIpv4/text()"os,
      cidr_ipv6: ~x"./cidrIpv6/text()"os,
      prefix_list_id: ~x"./prefixListId/text()"os,
      referenced_group_info: [
        ~x"./referencedGroupInfo"o,
        group_id: ~x"./groupId/text()"os,
        peering_status: ~x"./peeringStatus/text()"os,
        user_id: ~x"./userId/text()"os,
        vpc_id: ~x"./vpcId/text()"os,
        vpc_peering_connection_id: ~x"./vpcPeeringConnectionId/text()"os
      ],
      description: ~x"./description/text()"os,
      tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s],
      security_group_rule_arn: ~x"./securityGroupRuleArn/text()"os
    )
  end

  defp parse_ip_permission_set(body) do
    xpath(body, ~x"//unknownIpPermissionSet/item"l,
      ip_protocol: ~x"./ipProtocol/text()"os,
      from_port: ~x"./fromPort/text()"oi,
      to_port: ~x"./toPort/text()"oi,
      ip_ranges: [
        ~x"./ipRanges/item"l,
        cidr_ip: ~x"./cidrIp/text()"s,
        description: ~x"./description/text()"os
      ],
      ipv6_ranges: [
        ~x"./ipv6Ranges/item"l,
        cidr_ipv6: ~x"./cidrIpv6/text()"s,
        description: ~x"./description/text()"os
      ],
      prefix_list_ids: [
        ~x"./prefixListIds/item"l,
        prefix_list_id: ~x"./prefixListId/text()"s,
        description: ~x"./description/text()"os
      ],
      groups: [
        ~x"./groups/item"l,
        group_id: ~x"./groupId/text()"os,
        group_name: ~x"./groupName/text()"os,
        user_id: ~x"./userId/text()"os,
        vpc_id: ~x"./vpcId/text()"os,
        vpc_peering_connection_id: ~x"./vpcPeeringConnectionId/text()"os,
        peering_status: ~x"./peeringStatus/text()"os,
        description: ~x"./description/text()"os
      ]
    )
  end

  @doc """
  Describes security group rules — the rule-granular read (one entry per
  rule, each with its own `security_group_rule_id`).

  ## Options

    * `:security_group_rule_ids` - List of rule IDs, encoded as
      `SecurityGroupRuleId.N`.
    * `:filters` - List of `%{name:, values:}` filters (e.g.
      `%{name: "group-id", values: ["sg-1"]}`).
    * `:next_token`, `:max_results` - Pagination.

  ## Examples

      AwsSdk.EC2.describe_security_group_rules(
        filters: [%{name: "group-id", values: ["sg-0abc"]}]
      )
      #=> {:ok,
      #=>  %{
      #=>    security_group_rule_set: [
      #=>      %{
      #=>        security_group_rule_id: "sgr-0abc",
      #=>        group_id: "sg-0abc",
      #=>        group_owner_id: "123456789012",
      #=>        is_egress: false,
      #=>        ip_protocol: "tcp",
      #=>        from_port: 443,
      #=>        to_port: 443,
      #=>        cidr_ipv4: "0.0.0.0/0",
      #=>        cidr_ipv6: "",
      #=>        prefix_list_id: "",
      #=>        referenced_group_info: nil,
      #=>        description: "",
      #=>        tag_set: []
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}
  """
  @spec describe_security_group_rules(opts :: keyword()) ::
          {:ok, %{security_group_rule_set: list(map()), next_token: String.t() | nil}}
          | {:error, term()}
  def describe_security_group_rules(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_security_group_rules_response(opts)
    else
      do_describe_security_group_rules(opts)
    end
  end

  defp do_describe_security_group_rules(opts) do
    params =
      %{}
      |> put_member_list("SecurityGroupRuleId", opts[:security_group_rule_ids] || [])
      |> put_filters(opts[:filters] || [])
      |> maybe_put("NextToken", opts[:next_token])
      |> maybe_put("MaxResults", opts[:max_results])

    with {:ok, op} <- build_operation("DescribeSecurityGroupRules", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_describe_security_group_rules(body)}
    end
  end

  @doc false
  def parse_describe_security_group_rules_for_test(xml),
    do: parse_describe_security_group_rules(xml)

  defp parse_describe_security_group_rules(body) do
    rules =
      xpath(body, ~x"//securityGroupRuleSet/item"l,
        security_group_rule_id: ~x"./securityGroupRuleId/text()"s,
        group_id: ~x"./groupId/text()"os,
        group_owner_id: ~x"./groupOwnerId/text()"os,
        is_egress: ~x"./isEgress/text()"s,
        ip_protocol: ~x"./ipProtocol/text()"os,
        from_port: ~x"./fromPort/text()"oi,
        to_port: ~x"./toPort/text()"oi,
        cidr_ipv4: ~x"./cidrIpv4/text()"os,
        cidr_ipv6: ~x"./cidrIpv6/text()"os,
        prefix_list_id: ~x"./prefixListId/text()"os,
        referenced_group_info: [
          ~x"./referencedGroupInfo"o,
          group_id: ~x"./groupId/text()"os,
          peering_status: ~x"./peeringStatus/text()"os,
          user_id: ~x"./userId/text()"os,
          vpc_id: ~x"./vpcId/text()"os,
          vpc_peering_connection_id: ~x"./vpcPeeringConnectionId/text()"os
        ],
        description: ~x"./description/text()"os,
        security_group_rule_arn: ~x"./securityGroupRuleArn/text()"os,
        tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
      )

    %{
      security_group_rule_set: Enum.map(rules, &coerce_is_egress/1),
      next_token: xpath(body, ~x"//DescribeSecurityGroupRulesResponse/nextToken/text()"os)
    }
  end

  defp coerce_is_egress(%{is_egress: value} = rule) do
    %{rule | is_egress: value === "true"}
  end

  # `<return>` is a plain boolean on every mutating EC2 operation.
  defp parse_return(body) do
    %{return: xpath(body, ~x"//return/text()"os) == "true"}
  end

  # ---------------------------------------------------------------------------
  # VPCs / Subnets
  # ---------------------------------------------------------------------------

  @doc """
  Describes one or more VPCs.

  ## Options

    * `:vpc_ids` - List of VPC IDs.
    * `:filters` - List of `%{name:, values:}` filters.

  ## Examples

      AwsSdk.EC2.describe_vpcs(filters: [%{name: "isDefault", values: ["true"]}])
      #=> {:ok,
      #=>  %{
      #=>    vpc_set: [
      #=>      %{
      #=>        vpc_id: "vpc-1a2b3c4d",
      #=>        cidr_block: "10.0.0.0/16",
      #=>        state: "available",
      #=>        is_default: true,
      #=>        owner_id: "123456789012",
      #=>        dhcp_options_id: "dopt-7a8b9c2d",
      #=>        instance_tenancy: "default",
      #=>        cidr_block_association_set: [
      #=>          %{
      #=>            cidr_block: "10.0.0.0/16",
      #=>            association_id: "vpc-cidr-assoc-a2b3c4d5",
      #=>            cidr_block_state: %{state: "associated", status_message: ""}
      #=>          }
      #=>        ],
      #=>        ipv6_cidr_block_association_set: [],
      #=>        tag_set: [%{key: "Name", value: "prod"}],
      #=>        block_public_access_states: nil
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}

  `:is_default` is a real boolean; every other flag AWS models as a String
  (`"true"` / `"false"`) is left as sent.
  """
  @spec describe_vpcs(opts :: keyword()) ::
          {:ok, %{vpc_set: list(map()), next_token: String.t() | nil}} | {:error, term()}
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

    with {:ok, op} <- build_operation("DescribeVpcs", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      vpcs =
        xpath(body, ~x"//vpcSet/item"l,
          vpc_id: ~x"./vpcId/text()"s,
          cidr_block: ~x"./cidrBlock/text()"s,
          state: ~x"./state/text()"s,
          is_default: ~x"./isDefault/text()"s,
          owner_id: ~x"./ownerId/text()"os,
          dhcp_options_id: ~x"./dhcpOptionsId/text()"os,
          instance_tenancy: ~x"./instanceTenancy/text()"os,
          cidr_block_association_set: [
            ~x"./cidrBlockAssociationSet/item"l,
            cidr_block: ~x"./cidrBlock/text()"s,
            association_id: ~x"./associationId/text()"s,
            cidr_block_state: [
              ~x"./cidrBlockState"o,
              state: ~x"./state/text()"s,
              status_message: ~x"./statusMessage/text()"os
            ]
          ],
          ipv6_cidr_block_association_set: [
            ~x"./ipv6CidrBlockAssociationSet/item"l,
            ipv6_cidr_block: ~x"./ipv6CidrBlock/text()"s,
            association_id: ~x"./associationId/text()"s,
            ipv6_cidr_block_state: [
              ~x"./ipv6CidrBlockState"o,
              state: ~x"./state/text()"s,
              status_message: ~x"./statusMessage/text()"os
            ],
            ipv6_pool: ~x"./ipv6Pool/text()"os,
            ipv6_address_attribute: ~x"./ipv6AddressAttribute/text()"os,
            ip_source: ~x"./ipSource/text()"os,
            network_border_group: ~x"./networkBorderGroup/text()"os
          ],
          tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s],
          block_public_access_states: [
            ~x"./blockPublicAccessStates"o,
            internet_gateway_block_mode: ~x"./internetGatewayBlockMode/text()"os
          ]
        )

      {:ok,
       %{
         vpc_set: Enum.map(vpcs, &coerce_is_default/1),
         next_token: xpath(body, ~x"//DescribeVpcsResponse/nextToken/text()"os)
       }}
    end
  end

  defp coerce_is_default(%{is_default: value} = vpc) do
    %{vpc | is_default: value === "true"}
  end

  @doc """
  Describes network ACLs.

  ## Options

    * `:network_acl_ids` - List of ACL IDs, encoded as `NetworkAclId.N`.
    * `:filters` - List of `%{name:, values:}` filters (e.g.
      `%{name: "vpc-id", values: ["vpc-1"]}`).
    * `:next_token`, `:max_results` - Pagination.

  ## Examples

      AwsSdk.EC2.describe_network_acls(filters: [%{name: "vpc-id", values: ["vpc-0abc"]}])
      #=> {:ok,
      #=>  %{
      #=>    network_acl_set: [
      #=>      %{
      #=>        network_acl_id: "acl-0abc",
      #=>        vpc_id: "vpc-0abc",
      #=>        default: true,
      #=>        owner_id: "123456789012",
      #=>        entry_set: [
      #=>          %{
      #=>            rule_number: 100,
      #=>            protocol: "-1",
      #=>            rule_action: "allow",
      #=>            egress: false,
      #=>            cidr_block: "0.0.0.0/0",
      #=>            ipv6_cidr_block: nil,
      #=>            icmp_type_code: nil,
      #=>            port_range: nil
      #=>          }
      #=>        ],
      #=>        association_set: [
      #=>          %{
      #=>            network_acl_association_id: "aclassoc-1",
      #=>            network_acl_id: "acl-0abc",
      #=>            subnet_id: "subnet-1"
      #=>          }
      #=>        ],
      #=>        tag_set: []
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}
  """
  @spec describe_network_acls(opts :: keyword()) ::
          {:ok, %{network_acl_set: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def describe_network_acls(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_network_acls_response(opts)
    else
      do_describe_network_acls(opts)
    end
  end

  defp do_describe_network_acls(opts) do
    params =
      %{}
      |> put_member_list("NetworkAclId", opts[:network_acl_ids] || [])
      |> put_filters(opts[:filters] || [])
      |> maybe_put("NextToken", opts[:next_token])
      |> maybe_put("MaxResults", opts[:max_results])

    with {:ok, op} <- build_operation("DescribeNetworkAcls", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_describe_network_acls(body)}
    end
  end

  @doc false
  def parse_describe_network_acls_for_test(xml), do: parse_describe_network_acls(xml)

  defp parse_describe_network_acls(body) do
    acls =
      xpath(body, ~x"//networkAclSet/item"l,
        network_acl_id: ~x"./networkAclId/text()"s,
        vpc_id: ~x"./vpcId/text()"os,
        default: ~x"./default/text()"s,
        owner_id: ~x"./ownerId/text()"os,
        entry_set: [
          ~x"./entrySet/item"l,
          rule_number: ~x"./ruleNumber/text()"oi,
          # protocol is "-1" or an IANA number; AWS types it as a string.
          protocol: ~x"./protocol/text()"os,
          rule_action: ~x"./ruleAction/text()"os,
          egress: ~x"./egress/text()"s,
          cidr_block: ~x"./cidrBlock/text()"os,
          ipv6_cidr_block: ~x"./ipv6CidrBlock/text()"os,
          icmp_type_code: [
            ~x"./icmpTypeCode"o,
            code: ~x"./code/text()"oi,
            type: ~x"./type/text()"oi
          ],
          port_range: [~x"./portRange"o, from: ~x"./from/text()"oi, to: ~x"./to/text()"oi]
        ],
        association_set: [
          ~x"./associationSet/item"l,
          network_acl_association_id: ~x"./networkAclAssociationId/text()"s,
          network_acl_id: ~x"./networkAclId/text()"os,
          subnet_id: ~x"./subnetId/text()"os
        ],
        tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
      )

    %{
      network_acl_set: Enum.map(acls, &coerce_network_acl/1),
      next_token: xpath(body, ~x"//DescribeNetworkAclsResponse/nextToken/text()"os)
    }
  end

  defp coerce_network_acl(%{default: default, entry_set: entries} = acl) do
    %{
      acl
      | default: default === "true",
        entry_set: Enum.map(entries, &coerce_network_acl_entry/1)
    }
  end

  defp coerce_network_acl_entry(%{egress: egress} = entry) do
    %{entry | egress: egress === "true"}
  end

  @doc """
  Describes route tables.

  ## Options

    * `:route_table_ids` - List of route table IDs, encoded as `RouteTableId.N`.
    * `:filters` - List of `%{name:, values:}` filters.
    * `:next_token`, `:max_results` - Pagination.

  ## Examples

      AwsSdk.EC2.describe_route_tables(filters: [%{name: "vpc-id", values: ["vpc-0abc"]}])
      #=> {:ok,
      #=>  %{
      #=>    route_table_set: [
      #=>      %{
      #=>        route_table_id: "rtb-0abc",
      #=>        vpc_id: "vpc-0abc",
      #=>        owner_id: "123456789012",
      #=>        route_set: [
      #=>          %{
      #=>            destination_cidr_block: "0.0.0.0/0",
      #=>            gateway_id: "igw-0abc",
      #=>            state: "active",
      #=>            origin: "CreateRoute",
      #=>            nat_gateway_id: ""
      #=>          }
      #=>        ],
      #=>        association_set: [
      #=>          %{
      #=>            route_table_association_id: "rtbassoc-1",
      #=>            route_table_id: "rtb-0abc",
      #=>            subnet_id: "subnet-1",
      #=>            gateway_id: "",
      #=>            main: false,
      #=>            association_state: %{state: "associated", status_message: ""}
      #=>          }
      #=>        ],
      #=>        propagating_vgw_set: [],
      #=>        tag_set: []
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}

  Only the commonly-read route members are shown; the parser returns every
  documented member of the response.
  """
  @spec describe_route_tables(opts :: keyword()) ::
          {:ok, %{route_table_set: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def describe_route_tables(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_route_tables_response(opts)
    else
      do_describe_route_tables(opts)
    end
  end

  defp do_describe_route_tables(opts) do
    params =
      %{}
      |> put_member_list("RouteTableId", opts[:route_table_ids] || [])
      |> put_filters(opts[:filters] || [])
      |> maybe_put("NextToken", opts[:next_token])
      |> maybe_put("MaxResults", opts[:max_results])

    with {:ok, op} <- build_operation("DescribeRouteTables", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_describe_route_tables(body)}
    end
  end

  @doc false
  def parse_describe_route_tables_for_test(xml), do: parse_describe_route_tables(xml)

  defp parse_describe_route_tables(body) do
    tables =
      xpath(body, ~x"//routeTableSet/item"l,
        route_table_id: ~x"./routeTableId/text()"s,
        vpc_id: ~x"./vpcId/text()"os,
        owner_id: ~x"./ownerId/text()"os,
        route_set: [
          ~x"./routeSet/item"l,
          destination_cidr_block: ~x"./destinationCidrBlock/text()"os,
          destination_ipv6_cidr_block: ~x"./destinationIpv6CidrBlock/text()"os,
          destination_prefix_list_id: ~x"./destinationPrefixListId/text()"os,
          egress_only_internet_gateway_id: ~x"./egressOnlyInternetGatewayId/text()"os,
          gateway_id: ~x"./gatewayId/text()"os,
          instance_id: ~x"./instanceId/text()"os,
          instance_owner_id: ~x"./instanceOwnerId/text()"os,
          nat_gateway_id: ~x"./natGatewayId/text()"os,
          transit_gateway_id: ~x"./transitGatewayId/text()"os,
          local_gateway_id: ~x"./localGatewayId/text()"os,
          carrier_gateway_id: ~x"./carrierGatewayId/text()"os,
          network_interface_id: ~x"./networkInterfaceId/text()"os,
          vpc_peering_connection_id: ~x"./vpcPeeringConnectionId/text()"os,
          core_network_arn: ~x"./coreNetworkArn/text()"os,
          state: ~x"./state/text()"os,
          origin: ~x"./origin/text()"os
        ],
        association_set: [
          ~x"./associationSet/item"l,
          route_table_association_id: ~x"./routeTableAssociationId/text()"s,
          route_table_id: ~x"./routeTableId/text()"os,
          subnet_id: ~x"./subnetId/text()"os,
          gateway_id: ~x"./gatewayId/text()"os,
          main: ~x"./main/text()"s,
          association_state: [
            ~x"./associationState"o,
            state: ~x"./state/text()"os,
            status_message: ~x"./statusMessage/text()"os
          ]
        ],
        propagating_vgw_set: [~x"./propagatingVgwSet/item"l, gateway_id: ~x"./gatewayId/text()"s],
        tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
      )

    %{
      route_table_set: Enum.map(tables, &coerce_route_table/1),
      next_token: xpath(body, ~x"//DescribeRouteTablesResponse/nextToken/text()"os)
    }
  end

  defp coerce_route_table(%{association_set: assocs} = table) do
    %{table | association_set: Enum.map(assocs, &coerce_route_table_association/1)}
  end

  defp coerce_route_table_association(%{main: main} = assoc) do
    %{assoc | main: main === "true"}
  end

  @doc """
  Describes one or more subnets.

  ## Options

    * `:subnet_ids` - List of subnet IDs.
    * `:filters` - List of `%{name:, values:}` filters.

  ## Examples

      AwsSdk.EC2.describe_subnets(filters: [%{name: "vpc-id", values: ["vpc-1a2b3c4d"]}])
      #=> {:ok,
      #=>  %{
      #=>    subnet_set: [
      #=>      %{
      #=>        subnet_id: "subnet-9d4a7b6c",
      #=>        vpc_id: "vpc-1a2b3c4d",
      #=>        cidr_block: "10.0.1.0/24",
      #=>        availability_zone: "us-east-1a",
      #=>        availability_zone_id: "use1-az2",
      #=>        state: "available",
      #=>        subnet_arn: "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-9d4a7b6c",
      #=>        owner_id: "123456789012",
      #=>        available_ip_address_count: 251,
      #=>        default_for_az: "false",
      #=>        map_public_ip_on_launch: "false",
      #=>        ipv6_cidr_block_association_set: [],
      #=>        tag_set: [%{key: "Name", value: "private-a"}]
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}

  `:available_ip_address_count` is `nil` on IPv6-only subnets, where AWS
  omits it.
  """
  @spec describe_subnets(opts :: keyword()) ::
          {:ok, %{subnet_set: list(map()), next_token: String.t() | nil}} | {:error, term()}
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

    with {:ok, op} <- build_operation("DescribeSubnets", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      subnets =
        xpath(body, ~x"//subnetSet/item"l,
          subnet_id: ~x"./subnetId/text()"s,
          vpc_id: ~x"./vpcId/text()"s,
          cidr_block: ~x"./cidrBlock/text()"s,
          availability_zone: ~x"./availabilityZone/text()"s,
          state: ~x"./state/text()"s,
          subnet_arn: ~x"./subnetArn/text()"os,
          owner_id: ~x"./ownerId/text()"os,
          availability_zone_id: ~x"./availabilityZoneId/text()"os,
          # Required: No -- meaningless on IPv6-only subnets, so never a
          # plain integer cast.
          available_ip_address_count: ~x"./availableIpAddressCount/text()"oi,
          enable_lni_at_device_index: ~x"./enableLniAtDeviceIndex/text()"oi,
          default_for_az: ~x"./defaultForAz/text()"os,
          map_public_ip_on_launch: ~x"./mapPublicIpOnLaunch/text()"os,
          assign_ipv6_address_on_creation: ~x"./assignIpv6AddressOnCreation/text()"os,
          map_customer_owned_ip_on_launch: ~x"./mapCustomerOwnedIpOnLaunch/text()"os,
          customer_owned_ipv4_pool: ~x"./customerOwnedIpv4Pool/text()"os,
          outpost_arn: ~x"./outpostArn/text()"os,
          enable_dns64: ~x"./enableDns64/text()"os,
          ipv6_native: ~x"./ipv6Native/text()"os,
          type: ~x"./type/text()"os,
          ipv6_cidr_block_association_set: [
            ~x"./ipv6CidrBlockAssociationSet/item"l,
            ipv6_cidr_block: ~x"./ipv6CidrBlock/text()"s,
            association_id: ~x"./associationId/text()"s,
            # The wire element is ipv6CidrBlockState even though the shape is
            # named SubnetCidrBlockState.
            ipv6_cidr_block_state: [
              ~x"./ipv6CidrBlockState"o,
              state: ~x"./state/text()"s,
              status_message: ~x"./statusMessage/text()"os
            ],
            ipv6_address_attribute: ~x"./ipv6AddressAttribute/text()"os,
            ip_source: ~x"./ipSource/text()"os
          ],
          tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
        )

      {:ok,
       %{
         subnet_set: subnets,
         next_token: xpath(body, ~x"//DescribeSubnetsResponse/nextToken/text()"os)
       }}
    end
  end

  # ---------------------------------------------------------------------------
  # Instances
  # ---------------------------------------------------------------------------

  @doc """
  Describes one or more instances, grouped by reservation.

  Returns `%{reservation_set: [...], next_token: ...}`, mirroring AWS's
  `DescribeInstances` response: each reservation carries an `:instances_set`,
  and each instance keeps AWS's own nesting (`:instance_state`, `:placement`,
  `:cpu_options`, `:metadata_options`, `:tag_set`, `:group_set`, ...).

  ## Options

    * `:instance_ids` - List of instance IDs to describe.
    * `:filters` - List of `%{name:, values:}` filters.

  ## Examples

      AwsSdk.EC2.describe_instances(instance_ids: ["i-1234567890abcdef0"])
      #=> {:ok,
      #=>  %{
      #=>    reservation_set: [
      #=>      %{
      #=>        reservation_id: "r-1a2b3c4d",
      #=>        owner_id: "123456789012",
      #=>        requester_id: "",
      #=>        instances_set: [
      #=>          %{
      #=>            instance_id: "i-1234567890abcdef0",
      #=>            image_id: "ami-0abcdef1234567890",
      #=>            instance_type: "t3.micro",
      #=>            instance_state: %{code: 16, name: "running"},
      #=>            private_ip_address: "10.0.1.5",
      #=>            ip_address: "54.0.0.1",
      #=>            private_dns_name: "ip-10-0-1-5.ec2.internal",
      #=>            dns_name: "ec2-54-0-0-1.compute-1.amazonaws.com",
      #=>            subnet_id: "subnet-9d4a7b6c",
      #=>            vpc_id: "vpc-1a2b3c4d",
      #=>            launch_time: "2026-01-01T00:00:00.000Z",
      #=>            placement: %{
      #=>              availability_zone: "us-east-1a",
      #=>              group_name: "",
      #=>              tenancy: "default",
      #=>              partition_number: nil
      #=>            },
      #=>            cpu_options: %{core_count: 1, threads_per_core: 2, amd_sev_snp: ""},
      #=>            metadata_options: %{
      #=>              state: "applied",
      #=>              http_tokens: "required",
      #=>              http_endpoint: "enabled",
      #=>              http_put_response_hop_limit: 2
      #=>            },
      #=>            iam_instance_profile: %{
      #=>              arn: "arn:aws:iam::123456789012:instance-profile/app",
      #=>              id: "AIPA1EXAMPLE"
      #=>            },
      #=>            monitoring: %{state: "disabled"},
      #=>            state_reason: nil,
      #=>            block_device_mapping: [
      #=>              %{
      #=>                device_name: "/dev/xvda",
      #=>                ebs: %{
      #=>                  volume_id: "vol-0a1b2c3d",
      #=>                  status: "attached",
      #=>                  attach_time: "2026-01-01T00:00:00.000Z",
      #=>                  delete_on_termination: "true"
      #=>                }
      #=>              }
      #=>            ],
      #=>            network_interface_set: [
      #=>              %{
      #=>                network_interface_id: "eni-0a1b2c3d",
      #=>                subnet_id: "subnet-9d4a7b6c",
      #=>                status: "in-use",
      #=>                association: %{public_ip: "54.0.0.1", ip_owner_id: "amazon"},
      #=>                attachment: %{attachment_id: "eni-attach-0a1b", device_index: 0},
      #=>                group_set: [%{group_id: "sg-1a2b3c4d", group_name: "WebServers"}],
      #=>                private_ip_addresses_set: [
      #=>                  %{private_ip_address: "10.0.1.5", primary: "true"}
      #=>                ],
      #=>                ipv6_addresses_set: []
      #=>              }
      #=>            ],
      #=>            tag_set: [%{key: "Name", value: "web-1"}],
      #=>            group_set: [%{group_id: "sg-1a2b3c4d", group_name: "WebServers"}]
      #=>          }
      #=>        ]
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}

  Only the commonly-read members are shown; the parser returns every
  documented member of the response. Note the state is
  `instance_state.name`, not a top-level `:state`, and the public address is
  `:ip_address`, which is AWS's member name.
  """
  @spec describe_instances(opts :: keyword()) ::
          {:ok, %{reservation_set: list(map()), next_token: String.t() | nil}}
          | {:error, term()}
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

    with {:ok, op} <- build_operation("DescribeInstances", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_describe_instances(body)}
    end
  end

  @doc false
  def parse_describe_instances_for_test(xml), do: parse_describe_instances(xml)

  defp parse_describe_instances(body) do
    reservations =
      xpath(body, ~x"//reservationSet/item"l,
        reservation_id: ~x"./reservationId/text()"s,
        owner_id: ~x"./ownerId/text()"s,
        requester_id: ~x"./requesterId/text()"os,
        instances_set: [
          ~x"./instancesSet/item"l,
          instance_id: ~x"./instanceId/text()"s,
          image_id: ~x"./imageId/text()"s,
          instance_type: ~x"./instanceType/text()"s,
          instance_state: [
            ~x"./instanceState"o,
            # Required: No on every EC2 member, so no integer is ever cast
            # unconditionally in this module.
            code: ~x"./code/text()"oi,
            name: ~x"./name/text()"os
          ],
          private_ip_address: ~x"./privateIpAddress/text()"s,
          ip_address: ~x"./ipAddress/text()"s,
          subnet_id: ~x"./subnetId/text()"s,
          vpc_id: ~x"./vpcId/text()"s,
          launch_time: ~x"./launchTime/text()"s,
          ami_launch_index: ~x"./amiLaunchIndex/text()"oi,
          private_dns_name: ~x"./privateDnsName/text()"os,
          dns_name: ~x"./dnsName/text()"os,
          reason: ~x"./reason/text()"os,
          key_name: ~x"./keyName/text()"os,
          source_dest_check: ~x"./sourceDestCheck/text()"os,
          architecture: ~x"./architecture/text()"os,
          root_device_type: ~x"./rootDeviceType/text()"os,
          root_device_name: ~x"./rootDeviceName/text()"os,
          virtualization_type: ~x"./virtualizationType/text()"os,
          client_token: ~x"./clientToken/text()"os,
          hypervisor: ~x"./hypervisor/text()"os,
          ebs_optimized: ~x"./ebsOptimized/text()"os,
          kernel_id: ~x"./kernelId/text()"os,
          ramdisk_id: ~x"./ramdiskId/text()"os,
          platform: ~x"./platform/text()"os,
          platform_details: ~x"./platformDetails/text()"os,
          usage_operation: ~x"./usageOperation/text()"os,
          usage_operation_update_time: ~x"./usageOperationUpdateTime/text()"os,
          sriov_net_support: ~x"./sriovNetSupport/text()"os,
          spot_instance_request_id: ~x"./spotInstanceRequestId/text()"os,
          instance_lifecycle: ~x"./instanceLifecycle/text()"os,
          capacity_reservation_id: ~x"./capacityReservationId/text()"os,
          capacity_block_id: ~x"./capacityBlockId/text()"os,
          boot_mode: ~x"./bootMode/text()"os,
          current_instance_boot_mode: ~x"./currentInstanceBootMode/text()"os,
          ipv6_address: ~x"./ipv6Address/text()"os,
          tpm_support: ~x"./tpmSupport/text()"os,
          outpost_arn: ~x"./outpostArn/text()"os,
          monitoring: [~x"./monitoring"o, state: ~x"./state/text()"os],
          state_reason: [
            ~x"./stateReason"o,
            code: ~x"./code/text()"os,
            message: ~x"./message/text()"os
          ],
          iam_instance_profile: [
            ~x"./iamInstanceProfile"o,
            arn: ~x"./arn/text()"os,
            id: ~x"./id/text()"os
          ],
          placement: [
            ~x"./placement"o,
            availability_zone: ~x"./availabilityZone/text()"os,
            group_name: ~x"./groupName/text()"os,
            group_id: ~x"./groupId/text()"os,
            tenancy: ~x"./tenancy/text()"os,
            affinity: ~x"./affinity/text()"os,
            host_id: ~x"./hostId/text()"os,
            host_resource_group_arn: ~x"./hostResourceGroupArn/text()"os,
            availability_zone_id: ~x"./availabilityZoneId/text()"os,
            spread_domain: ~x"./spreadDomain/text()"os,
            partition_number: ~x"./partitionNumber/text()"oi
          ],
          cpu_options: [
            ~x"./cpuOptions"o,
            core_count: ~x"./coreCount/text()"oi,
            threads_per_core: ~x"./threadsPerCore/text()"oi,
            amd_sev_snp: ~x"./amdSevSnp/text()"os
          ],
          # The docs' Example 9 renders this block in PascalCase; a live
          # DescribeInstances response uses lowerCamel like every other
          # structure, so the example is a doc typo.
          metadata_options: [
            ~x"./metadataOptions"o,
            http_tokens: ~x"./httpTokens/text()"os,
            http_endpoint: ~x"./httpEndpoint/text()"os,
            http_protocol_ipv6: ~x"./httpProtocolIpv6/text()"os,
            instance_metadata_tags: ~x"./instanceMetadataTags/text()"os,
            state: ~x"./state/text()"os,
            http_put_response_hop_limit: ~x"./httpPutResponseHopLimit/text()"oi
          ],
          enclave_options: [~x"./enclaveOptions"o, enabled: ~x"./enabled/text()"os],
          hibernation_options: [
            ~x"./hibernationOptions"o,
            configured: ~x"./configured/text()"os
          ],
          maintenance_options: [
            ~x"./maintenanceOptions"o,
            auto_recovery: ~x"./autoRecovery/text()"os,
            reboot_migration: ~x"./rebootMigration/text()"os
          ],
          private_dns_name_options: [
            ~x"./privateDnsNameOptions"o,
            hostname_type: ~x"./hostnameType/text()"os,
            enable_resource_name_dns_a_record: ~x"./enableResourceNameDnsARecord/text()"os,
            enable_resource_name_dns_aaaa_record: ~x"./enableResourceNameDnsAAAARecord/text()"os
          ],
          capacity_reservation_specification: [
            ~x"./capacityReservationSpecification"o,
            capacity_reservation_preference: ~x"./capacityReservationPreference/text()"os,
            capacity_reservation_target: [
              ~x"./capacityReservationTarget"o,
              capacity_reservation_id: ~x"./capacityReservationId/text()"os,
              capacity_reservation_resource_group_arn:
                ~x"./capacityReservationResourceGroupArn/text()"os
            ]
          ],
          product_codes: [
            ~x"./productCodes/item"l,
            product_code: ~x"./productCode/text()"s,
            type: ~x"./type/text()"os
          ],
          block_device_mapping: [
            ~x"./blockDeviceMapping/item"l,
            device_name: ~x"./deviceName/text()"s,
            ebs: [
              ~x"./ebs"o,
              volume_id: ~x"./volumeId/text()"os,
              status: ~x"./status/text()"os,
              attach_time: ~x"./attachTime/text()"os,
              delete_on_termination: ~x"./deleteOnTermination/text()"os,
              volume_owner_id: ~x"./volumeOwnerId/text()"os,
              associated_resource: ~x"./associatedResource/text()"os,
              ebs_card_index: ~x"./ebsCardIndex/text()"oi
            ]
          ],
          network_interface_set: [
            ~x"./networkInterfaceSet/item"l,
            network_interface_id: ~x"./networkInterfaceId/text()"os,
            subnet_id: ~x"./subnetId/text()"os,
            vpc_id: ~x"./vpcId/text()"os,
            description: ~x"./description/text()"os,
            owner_id: ~x"./ownerId/text()"os,
            status: ~x"./status/text()"os,
            mac_address: ~x"./macAddress/text()"os,
            private_ip_address: ~x"./privateIpAddress/text()"os,
            private_dns_name: ~x"./privateDnsName/text()"os,
            source_dest_check: ~x"./sourceDestCheck/text()"os,
            interface_type: ~x"./interfaceType/text()"os,
            association: [
              ~x"./association"o,
              public_ip: ~x"./publicIp/text()"os,
              public_dns_name: ~x"./publicDnsName/text()"os,
              ip_owner_id: ~x"./ipOwnerId/text()"os,
              carrier_ip: ~x"./carrierIp/text()"os,
              customer_owned_ip: ~x"./customerOwnedIp/text()"os
            ],
            attachment: [
              ~x"./attachment"o,
              attachment_id: ~x"./attachmentId/text()"os,
              status: ~x"./status/text()"os,
              attach_time: ~x"./attachTime/text()"os,
              delete_on_termination: ~x"./deleteOnTermination/text()"os,
              device_index: ~x"./deviceIndex/text()"oi,
              network_card_index: ~x"./networkCardIndex/text()"oi,
              ena_queue_count: ~x"./enaQueueCount/text()"oi
            ],
            group_set: [
              ~x"./groupSet/item"l,
              group_id: ~x"./groupId/text()"s,
              group_name: ~x"./groupName/text()"s
            ],
            private_ip_addresses_set: [
              ~x"./privateIpAddressesSet/item"l,
              private_ip_address: ~x"./privateIpAddress/text()"os,
              private_dns_name: ~x"./privateDnsName/text()"os,
              primary: ~x"./primary/text()"os,
              association: [
                ~x"./association"o,
                public_ip: ~x"./publicIp/text()"os,
                ip_owner_id: ~x"./ipOwnerId/text()"os
              ]
            ],
            ipv6_addresses_set: [
              ~x"./ipv6AddressesSet/item"l,
              ipv6_address: ~x"./ipv6Address/text()"os,
              is_primary_ipv6: ~x"./isPrimaryIpv6/text()"os
            ]
          ],
          tag_set: [
            ~x"./tagSet/item"l,
            key: ~x"./key/text()"s,
            value: ~x"./value/text()"s
          ],
          group_set: [
            ~x"./groupSet/item"l,
            group_id: ~x"./groupId/text()"s,
            group_name: ~x"./groupName/text()"s
          ]
        ]
      )

    %{
      reservation_set: reservations,
      next_token: xpath(body, ~x"//DescribeInstancesResponse/nextToken/text()"os)
    }
  end

  # ---------------------------------------------------------------------------
  # Key pairs
  # ---------------------------------------------------------------------------

  @doc """
  Describes key pairs.

  ## Options

    * `:key_names` - List of key names, encoded as `KeyName.N`.
    * `:key_pair_ids` - List of key pair IDs, encoded as `KeyPairId.N`.
    * `:filters` - List of `%{name:, values:}` filters.
    * `:include_public_key` - Boolean; include the public key material.

  ## Examples

      AwsSdk.EC2.describe_key_pairs(filters: [%{name: "key-name", values: ["deploy"]}])
      #=> {:ok,
      #=>  %{
      #=>    key_set: [
      #=>      %{
      #=>        key_pair_id: "key-0abc",
      #=>        key_name: "deploy",
      #=>        key_fingerprint: "ab:cd:...",
      #=>        key_type: "ed25519",
      #=>        create_time: "2026-01-01T00:00:00Z",
      #=>        public_key: "",
      #=>        tag_set: []
      #=>      }
      #=>    ]
      #=>  }}
  """
  @spec describe_key_pairs(opts :: keyword()) ::
          {:ok, %{key_set: list(map())}} | {:error, term()}
  def describe_key_pairs(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_key_pairs_response(opts)
    else
      do_describe_key_pairs(opts)
    end
  end

  defp do_describe_key_pairs(opts) do
    params =
      %{}
      |> put_member_list("KeyName", opts[:key_names] || [])
      |> put_member_list("KeyPairId", opts[:key_pair_ids] || [])
      |> put_filters(opts[:filters] || [])
      |> maybe_put("IncludePublicKey", opts[:include_public_key])

    with {:ok, op} <- build_operation("DescribeKeyPairs", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_describe_key_pairs(body)}
    end
  end

  @doc false
  def parse_describe_key_pairs_for_test(xml), do: parse_describe_key_pairs(xml)

  defp parse_describe_key_pairs(body) do
    %{
      key_set:
        xpath(body, ~x"//keySet/item"l,
          key_pair_id: ~x"./keyPairId/text()"os,
          key_name: ~x"./keyName/text()"s,
          key_fingerprint: ~x"./keyFingerprint/text()"os,
          key_type: ~x"./keyType/text()"os,
          create_time: ~x"./createTime/text()"os,
          public_key: ~x"./publicKey/text()"os,
          tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
        )
    }
  end

  @doc """
  Deletes the specified key pair by name.

  ## Examples

      AwsSdk.EC2.delete_key_pair("deploy")
      #=> {:ok, %{return: true, key_pair_id: "key-0abc"}}
  """
  @spec delete_key_pair(key_name :: String.t(), opts :: keyword()) ::
          {:ok, %{return: boolean(), key_pair_id: String.t() | nil}} | {:error, term()}
  def delete_key_pair(key_name, opts \\ []) when is_binary(key_name) do
    if sandbox?(opts) do
      sandbox_delete_key_pair_response(key_name, opts)
    else
      do_delete_key_pair(key_name, opts)
    end
  end

  defp do_delete_key_pair(key_name, opts) do
    with {:ok, op} <- build_operation("DeleteKeyPair", %{"KeyName" => key_name}, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_delete_key_pair(body)}
    end
  end

  @doc false
  def parse_delete_key_pair_for_test(xml), do: parse_delete_key_pair(xml)

  defp parse_delete_key_pair(body) do
    %{
      return: xpath(body, ~x"//DeleteKeyPairResponse/return/text()"os) == "true",
      key_pair_id: xpath(body, ~x"//DeleteKeyPairResponse/keyPairId/text()"os)
    }
  end

  # ---------------------------------------------------------------------------
  # Instance lifecycle
  # ---------------------------------------------------------------------------

  @doc """
  Terminates the specified instances.

  ## Arguments

    * `instance_ids` - List of instance IDs, encoded as `InstanceId.N`.

  ## Examples

      AwsSdk.EC2.terminate_instances(["i-1234567890abcdef0"])
      #=> {:ok,
      #=>  %{
      #=>    instances_set: [
      #=>      %{
      #=>        instance_id: "i-1234567890abcdef0",
      #=>        current_state: %{code: 32, name: "shutting-down"},
      #=>        previous_state: %{code: 16, name: "running"}
      #=>      }
      #=>    ]
      #=>  }}
  """
  @spec terminate_instances(instance_ids :: [String.t()], opts :: keyword()) ::
          {:ok, %{instances_set: list(map())}} | {:error, term()}
  def terminate_instances([_ | _] = instance_ids, opts \\ []) do
    if sandbox?(opts) do
      sandbox_terminate_instances_response(instance_ids, opts)
    else
      do_terminate_instances(instance_ids, opts)
    end
  end

  defp do_terminate_instances(instance_ids, opts) do
    params = put_member_list(%{}, "InstanceId", instance_ids)

    with {:ok, op} <- build_operation("TerminateInstances", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_terminate_instances(body)}
    end
  end

  @doc false
  def parse_terminate_instances_for_test(xml), do: parse_terminate_instances(xml)

  defp parse_terminate_instances(body) do
    %{
      instances_set:
        xpath(body, ~x"//instancesSet/item"l,
          instance_id: ~x"./instanceId/text()"s,
          current_state: [
            ~x"./currentState"o,
            code: ~x"./code/text()"oi,
            name: ~x"./name/text()"os
          ],
          previous_state: [
            ~x"./previousState"o,
            code: ~x"./code/text()"oi,
            name: ~x"./name/text()"os
          ]
        )
    }
  end

  @doc """
  Gets the console output for the specified instance.

  AWS returns the output base64-encoded on the wire; this function decodes
  it, since the encoding is transport detail rather than content. If the
  payload is somehow not valid base64 it is returned as-is.

  ## Arguments

    * `instance_id` - The instance ID.

  ## Options

    * `:latest` - Boolean; when `true`, returns the latest output instead
      of the buffered post-boot snapshot.

  ## Examples

      AwsSdk.EC2.get_console_output("i-1234567890abcdef0", latest: true)
      #=> {:ok,
      #=>  %{
      #=>    instance_id: "i-1234567890abcdef0",
      #=>    timestamp: "2026-08-05T12:00:00.000Z",
      #=>    output: "[    0.000000] Linux version 6.1..."
      #=>  }}
  """
  @spec get_console_output(instance_id :: String.t(), opts :: keyword()) ::
          {:ok, %{instance_id: String.t(), timestamp: String.t() | nil, output: String.t() | nil}}
          | {:error, term()}
  def get_console_output(instance_id, opts \\ []) when is_binary(instance_id) do
    if sandbox?(opts) do
      sandbox_get_console_output_response(instance_id, opts)
    else
      do_get_console_output(instance_id, opts)
    end
  end

  defp do_get_console_output(instance_id, opts) do
    params =
      %{"InstanceId" => instance_id}
      |> maybe_put("Latest", opts[:latest])

    with {:ok, op} <- build_operation("GetConsoleOutput", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_get_console_output(body)}
    end
  end

  @doc false
  def parse_get_console_output_for_test(xml), do: parse_get_console_output(xml)

  defp parse_get_console_output(body) do
    result =
      xpath(body, ~x"//GetConsoleOutputResponse"e,
        instance_id: ~x"./instanceId/text()"s,
        timestamp: ~x"./timestamp/text()"os,
        output: ~x"./output/text()"os
      )

    %{result | output: decode_console_output(result.output)}
  end

  defp decode_console_output(nil), do: nil

  # SweetXml renders an absent <output> as "", but "no console output yet" is
  # not the same as "the console printed nothing", so it surfaces as nil.
  defp decode_console_output(""), do: nil

  defp decode_console_output(encoded) do
    # AWS base64-encodes the console text and may fold in whitespace.
    case Base.decode64(encoded, ignore: :whitespace) do
      {:ok, decoded} -> decoded
      :error -> encoded
    end
  end

  # ---------------------------------------------------------------------------
  # Images and snapshots
  # ---------------------------------------------------------------------------

  @doc """
  Describes AMIs.

  Returns `%{images_set: [...], next_token: ...}`. Each image keeps AWS's
  nesting: `:tag_set`, `:state_reason`, and `:block_device_mapping` whose
  entries carry a nested `:ebs` (nil for instance-store devices, which send
  no `<ebs>` element at all).

  ## Options

    * `:owners` - List of owner IDs or aliases (e.g. `["self"]`),
      encoded as `Owner.N`.
    * `:image_ids` - List of AMI IDs, encoded as `ImageId.N`.
    * `:filters` - List of `%{name:, values:}` filters. Filters with no
      values are dropped, because AWS rejects a filter name that carries
      no values.

      AwsSdk.EC2.describe_images(
        owners: ["self"],
        filters: [%{name: "tag:ReleaseGroup", values: ["deployd"]}]
      )

  ## Examples

      AwsSdk.EC2.describe_images(
        owners: ["self"],
        filters: [%{name: "tag:ReleaseGroup", values: ["deployd"]}]
      )
      #=> {:ok,
      #=>  %{
      #=>    images_set: [
      #=>      %{
      #=>        image_id: "ami-0abcdef1234567890",
      #=>        name: "app-2026-01-01",
      #=>        image_state: "available",
      #=>        image_owner_id: "123456789012",
      #=>        creation_date: "2026-01-01T00:00:00.000Z",
      #=>        architecture: "x86_64",
      #=>        root_device_type: "ebs",
      #=>        root_device_name: "/dev/xvda",
      #=>        virtualization_type: "hvm",
      #=>        is_public: "false",
      #=>        state_reason: nil,
      #=>        tag_set: [%{key: "ReleaseGroup", value: "deployd"}],
      #=>        block_device_mapping: [
      #=>          %{
      #=>            device_name: "/dev/xvda",
      #=>            virtual_name: "",
      #=>            no_device: "",
      #=>            ebs: %{
      #=>              snapshot_id: "snap-0a1b2c3d",
      #=>              volume_size: 30,
      #=>              volume_type: "gp3",
      #=>              delete_on_termination: "true"
      #=>            }
      #=>          },
      #=>          %{device_name: "/dev/sdb", virtual_name: "ephemeral0", ebs: nil}
      #=>        ]
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}

  An instance-store device carries no `<ebs>` element, so its `:ebs` is
  `nil` rather than a map of empty strings.
  """
  @spec describe_images(opts :: keyword()) ::
          {:ok, %{images_set: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def describe_images(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_images_response(opts)
    else
      do_describe_images(opts)
    end
  end

  defp do_describe_images(opts) do
    params =
      %{}
      |> put_member_list("Owner", opts[:owners] || [])
      |> put_member_list("ImageId", opts[:image_ids] || [])
      |> put_filters(reject_valueless_filters(opts[:filters] || []))

    with {:ok, op} <- build_operation("DescribeImages", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_describe_images(body)}
    end
  end

  @doc false
  def parse_describe_images_for_test(xml), do: parse_describe_images(xml)

  defp parse_describe_images(body) do
    images =
      xpath(body, ~x"//imagesSet/item"l,
        image_id: ~x"./imageId/text()"s,
        name: ~x"./name/text()"s,
        image_state: ~x"./imageState/text()"s,
        image_owner_id: ~x"./imageOwnerId/text()"s,
        creation_date: ~x"./creationDate/text()"s,
        tag_set: [
          ~x"./tagSet/item"l,
          key: ~x"./key/text()"s,
          value: ~x"./value/text()"s
        ],
        image_location: ~x"./imageLocation/text()"os,
        image_type: ~x"./imageType/text()"os,
        # Examples 2 and 3 and the current Contents use isPublic; Example 1
        # uses the stale `public`. Read the documented name.
        is_public: ~x"./isPublic/text()"os,
        image_owner_alias: ~x"./imageOwnerAlias/text()"os,
        description: ~x"./description/text()"os,
        architecture: ~x"./architecture/text()"os,
        # `platform` is a Windows-only flag; platformDetails is the general
        # field.
        platform: ~x"./platform/text()"os,
        platform_details: ~x"./platformDetails/text()"os,
        usage_operation: ~x"./usageOperation/text()"os,
        ena_support: ~x"./enaSupport/text()"os,
        sriov_net_support: ~x"./sriovNetSupport/text()"os,
        kernel_id: ~x"./kernelId/text()"os,
        ramdisk_id: ~x"./ramdiskId/text()"os,
        root_device_type: ~x"./rootDeviceType/text()"os,
        root_device_name: ~x"./rootDeviceName/text()"os,
        virtualization_type: ~x"./virtualizationType/text()"os,
        hypervisor: ~x"./hypervisor/text()"os,
        boot_mode: ~x"./bootMode/text()"os,
        tpm_support: ~x"./tpmSupport/text()"os,
        imds_support: ~x"./imdsSupport/text()"os,
        deprecation_time: ~x"./deprecationTime/text()"os,
        deregistration_protection: ~x"./deregistrationProtection/text()"os,
        last_launched_time: ~x"./lastLaunchedTime/text()"os,
        source_image_id: ~x"./sourceImageId/text()"os,
        source_image_region: ~x"./sourceImageRegion/text()"os,
        source_instance_id: ~x"./sourceInstanceId/text()"os,
        public_ssm_parameter_name: ~x"./publicSsmParameterName/text()"os,
        free_tier_eligible: ~x"./freeTierEligible/text()"os,
        image_allowed: ~x"./imageAllowed/text()"os,
        state_reason: [
          ~x"./stateReason"o,
          code: ~x"./code/text()"os,
          message: ~x"./message/text()"os
        ],
        product_codes: [
          ~x"./productCodes/item"l,
          product_code: ~x"./productCode/text()"s,
          type: ~x"./type/text()"os
        ],
        block_device_mapping: [
          ~x"./blockDeviceMapping/item"l,
          device_name: ~x"./deviceName/text()"s,
          virtual_name: ~x"./virtualName/text()"os,
          no_device: ~x"./noDevice/text()"os,
          # Instance-store devices carry no <ebs> child at all, so the
          # anchor is optional and the whole sub-map comes back nil.
          ebs: [
            ~x"./ebs"o,
            snapshot_id: ~x"./snapshotId/text()"os,
            # Every EBS integer is Required: No -- never a plain cast.
            volume_size: ~x"./volumeSize/text()"oi,
            iops: ~x"./iops/text()"oi,
            throughput: ~x"./throughput/text()"oi,
            ebs_card_index: ~x"./ebsCardIndex/text()"oi,
            volume_type: ~x"./volumeType/text()"os,
            delete_on_termination: ~x"./deleteOnTermination/text()"os,
            encrypted: ~x"./encrypted/text()"os,
            outpost_arn: ~x"./outpostArn/text()"os
          ]
        ]
      )

    %{
      images_set: images,
      next_token: xpath(body, ~x"//DescribeImagesResponse/nextToken/text()"os)
    }
  end

  defp reject_valueless_filters(filters) do
    Enum.reject(filters, fn filter ->
      (filter[:values] || filter["Values"] || []) === []
    end)
  end

  @doc """
  Deregisters an AMI.

  The backing snapshots are not deleted; delete them separately with
  `delete_snapshot/2`.

  ## Examples

      AwsSdk.EC2.deregister_image("ami-0abcdef1234567890")
      #=> {:ok, %{return: true, delete_associated_snapshot_result_set: []}}
  """
  @spec deregister_image(image_id :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def deregister_image(image_id, opts \\ []) do
    if sandbox?(opts) do
      sandbox_deregister_image_response(image_id, opts)
    else
      do_deregister_image(image_id, opts)
    end
  end

  defp do_deregister_image(image_id, opts) do
    with {:ok, op} <- build_operation("DeregisterImage", %{"ImageId" => image_id}, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok,
       Map.put(
         parse_return(body),
         :delete_associated_snapshot_result_set,
         xpath(body, ~x"//deleteSnapshotResultSet/item"l,
           snapshot_id: ~x"./snapshotId/text()"os,
           return_code: ~x"./returnCode/text()"os
         )
       )}
    end
  end

  @doc """
  Deletes an EBS snapshot.

  ## Examples

      AwsSdk.EC2.delete_snapshot("snap-0a1b2c3d")
      #=> {:ok, %{return: true}}
  """
  @spec delete_snapshot(snapshot_id :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def delete_snapshot(snapshot_id, opts \\ []) do
    if sandbox?(opts) do
      sandbox_delete_snapshot_response(snapshot_id, opts)
    else
      do_delete_snapshot(snapshot_id, opts)
    end
  end

  defp do_delete_snapshot(snapshot_id, opts) do
    with {:ok, op} <- build_operation("DeleteSnapshot", %{"SnapshotId" => snapshot_id}, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_return(body)}
    end
  end

  # ---------------------------------------------------------------------------
  # Tags
  # ---------------------------------------------------------------------------

  @doc """
  Adds or overwrites tags on one or more EC2 resources.

  `tags` is a list of `%{key:, value:}` maps or `{key, value}` tuples.

  ## Examples

      AwsSdk.EC2.create_tags(["i-1234567890abcdef0"], [%{key: "Name", value: "web-1"}])
      #=> {:ok, %{return: true}}

      # Tuples work too.
      AwsSdk.EC2.create_tags(["ami-0abcdef1234567890"], [{"ReleaseGroup", "deployd"}])
      #=> {:ok, %{return: true}}
  """
  @spec create_tags(
          resource_ids :: list(String.t()),
          tags :: list(map() | {String.t(), String.t()}),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
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

    with {:ok, op} <- build_operation("CreateTags", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_return(body)}
    end
  end

  # ---------------------------------------------------------------------------
  # Launch templates
  # ---------------------------------------------------------------------------

  @doc """
  Describes launch templates.

  Returns `%{launch_templates: [...], next_token: ...}`. Each entry carries
  the template's identity and version pointers (`:launch_template_id`,
  `:launch_template_name`, `:default_version_number`,
  `:latest_version_number`, `:tag_set`) but *not* its contents -- the
  configuration lives on a version, via `describe_launch_template_versions/1`.

  ## Options

    * `:launch_template_ids` - List of template IDs, encoded as `LaunchTemplateId.N`.
    * `:launch_template_names` - List of template names, encoded as `LaunchTemplateName.N`.
    * `:filters` - List of `%{name:, values:}` filters.
    * `:next_token` - Pagination token from a previous response.
    * `:max_results` - Maximum templates per page.

  ## Examples

      AwsSdk.EC2.describe_launch_templates(launch_template_names: ["web"])
      #=> {:ok,
      #=>  %{
      #=>    launch_templates: [
      #=>      %{
      #=>        launch_template_id: "lt-0a1b2c3d4e5f6789a",
      #=>        launch_template_name: "web",
      #=>        create_time: "2026-01-01T00:00:00.000Z",
      #=>        created_by: "arn:aws:iam::123456789012:user/deploy",
      #=>        default_version_number: 1,
      #=>        latest_version_number: 3,
      #=>        operator: nil,
      #=>        tag_set: [%{key: "env", value: "prod"}]
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}

  The configuration itself is not here -- fetch a version with
  `describe_launch_template_versions/1`.
  """
  @spec describe_launch_templates(opts :: keyword()) ::
          {:ok, %{launch_templates: list(map()), next_token: String.t() | nil}}
          | {:error, term()}
  def describe_launch_templates(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_launch_templates_response(opts)
    else
      do_describe_launch_templates(opts)
    end
  end

  defp do_describe_launch_templates(opts) do
    params =
      %{}
      |> put_member_list("LaunchTemplateId", opts[:launch_template_ids] || [])
      |> put_member_list("LaunchTemplateName", opts[:launch_template_names] || [])
      |> put_filters(opts[:filters] || [])
      |> maybe_put("NextToken", opts[:next_token])
      |> maybe_put("MaxResults", opts[:max_results])

    with {:ok, op} <- build_operation("DescribeLaunchTemplates", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_describe_launch_templates(body)}
    end
  end

  @doc false
  def parse_describe_launch_templates_for_test(xml), do: parse_describe_launch_templates(xml)

  defp parse_describe_launch_templates(body) do
    %{
      launch_templates:
        xpath(body, ~x"//launchTemplates/item"l,
          launch_template_id: ~x"./launchTemplateId/text()"s,
          launch_template_name: ~x"./launchTemplateName/text()"s,
          create_time: ~x"./createTime/text()"os,
          created_by: ~x"./createdBy/text()"os,
          default_version_number: ~x"./defaultVersionNumber/text()"oi,
          latest_version_number: ~x"./latestVersionNumber/text()"oi,
          operator: [
            ~x"./operator"o,
            managed: ~x"./managed/text()"os,
            principal: ~x"./principal/text()"os
          ],
          tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
        ),
      next_token: xpath(body, ~x"//DescribeLaunchTemplatesResponse/nextToken/text()"os)
    }
  end

  @doc """
  Describes launch template versions, including each version's
  `:launch_template_data`.

  Returns `%{launch_template_versions: [...], next_token: ...}`. The version
  metadata (`:version_number`, `:default_version`, `:create_time`, ...) sits
  alongside `:launch_template_data`, which mirrors AWS's `ResponseLaunchTemplateData`
  structure -- `:placement`, `:metadata_options`, `:iam_instance_profile` and
  friends are nested maps, and the repeated sets
  (`:block_device_mapping_set`, `:network_interface_set`, `:tag_specification_set`,
  `:security_group_id_set`) are lists.

  Supply exactly one of `:launch_template_id` or `:launch_template_name`; AWS
  rejects both together. Without `:versions`, AWS returns every version.

  ## Options

    * `:launch_template_id` - The template ID.
    * `:launch_template_name` - The template name.
    * `:versions` - List of version numbers, or `"$Latest"` / `"$Default"`.
    * `:min_version`, `:max_version` - Inclusive version range.
    * `:filters` - List of `%{name:, values:}` filters.
    * `:next_token`, `:max_results` - Pagination.
    * `:resolve_alias` - When `true`, resolves an AMI alias in `:image_id` to
      the underlying AMI ID.

  ## Examples

      AwsSdk.EC2.describe_launch_template_versions(
        launch_template_id: "lt-0a1b2c3d4e5f6789a",
        versions: ["$Latest"]
      )
      #=> {:ok,
      #=>  %{
      #=>    launch_template_versions: [
      #=>      %{
      #=>        launch_template_id: "lt-0a1b2c3d4e5f6789a",
      #=>        launch_template_name: "web",
      #=>        version_number: 3,
      #=>        version_description: "",
      #=>        create_time: "2026-01-01T00:00:00.000Z",
      #=>        created_by: "arn:aws:iam::123456789012:user/deploy",
      #=>        default_version: "false",
      #=>        operator: nil,
      #=>        launch_template_data: %{
      #=>          image_id: "ami-0abcdef1234567890",
      #=>          instance_type: "t3.micro",
      #=>          key_name: "deploy-key",
      #=>          # Base64, exactly as AWS stores it.
      #=>          user_data: "IyEvYmluL2Jhc2gKZWNobyBoaQ==",
      #=>          security_group_id_set: ["sg-1a2b3c4d"],
      #=>          iam_instance_profile: %{
      #=>            arn: "arn:aws:iam::123456789012:instance-profile/app",
      #=>            name: ""
      #=>          },
      #=>          placement: %{availability_zone: "us-east-1a", tenancy: "default"},
      #=>          metadata_options: %{
      #=>            http_tokens: "required",
      #=>            http_put_response_hop_limit: 2
      #=>          },
      #=>          instance_market_options: %{
      #=>            market_type: "spot",
      #=>            spot_options: %{max_price: "0.02", spot_instance_type: "one-time"}
      #=>          },
      #=>          block_device_mapping_set: [
      #=>            %{
      #=>              device_name: "/dev/xvda",
      #=>              ebs: %{volume_size: 30, volume_type: "gp3", delete_on_termination: "true"}
      #=>            }
      #=>          ],
      #=>          network_interface_set: [
      #=>            %{
      #=>              device_index: 0,
      #=>              subnet_id: "subnet-9d4a7b6c",
      #=>              associate_public_ip_address: "true",
      #=>              group_set: ["sg-1a2b3c4d"]
      #=>            }
      #=>          ],
      #=>          tag_specification_set: [
      #=>            %{
      #=>              resource_type: "instance",
      #=>              tag_set: [%{key: "Name", value: "web"}]
      #=>            }
      #=>          ]
      #=>        }
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}

  Every member of `:launch_template_data` is optional in AWS's model, so a
  minimal template returns mostly `nil` sub-structures and empty lists.
  """
  @spec describe_launch_template_versions(opts :: keyword()) ::
          {:ok, %{launch_template_versions: list(map()), next_token: String.t() | nil}}
          | {:error, term()}
  def describe_launch_template_versions(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_launch_template_versions_response(opts)
    else
      do_describe_launch_template_versions(opts)
    end
  end

  defp do_describe_launch_template_versions(opts) do
    params =
      %{}
      |> maybe_put("LaunchTemplateId", opts[:launch_template_id])
      |> maybe_put("LaunchTemplateName", opts[:launch_template_name])
      |> put_member_list("LaunchTemplateVersion", opts[:versions] || [])
      |> maybe_put("MinVersion", opts[:min_version])
      |> maybe_put("MaxVersion", opts[:max_version])
      |> maybe_put("ResolveAlias", opts[:resolve_alias])
      |> put_filters(opts[:filters] || [])
      |> maybe_put("NextToken", opts[:next_token])
      |> maybe_put("MaxResults", opts[:max_results])

    with {:ok, op} <- build_operation("DescribeLaunchTemplateVersions", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_describe_launch_template_versions(body)}
    end
  end

  @doc false
  def parse_describe_launch_template_versions_for_test(xml),
    do: parse_describe_launch_template_versions(xml)

  defp parse_describe_launch_template_versions(body) do
    %{
      launch_template_versions:
        xpath(
          body,
          ~x"//launchTemplateVersionSet/item"l,
          launch_template_id: ~x"./launchTemplateId/text()"s,
          launch_template_name: ~x"./launchTemplateName/text()"s,
          version_number: ~x"./versionNumber/text()"oi,
          version_description: ~x"./versionDescription/text()"os,
          create_time: ~x"./createTime/text()"os,
          created_by: ~x"./createdBy/text()"os,
          default_version: ~x"./defaultVersion/text()"os,
          operator: [
            ~x"./operator"o,
            managed: ~x"./managed/text()"os,
            principal: ~x"./principal/text()"os
          ],
          launch_template_data: [~x"./launchTemplateData"o | launch_template_data_fields()]
        ),
      next_token: xpath(body, ~x"//DescribeLaunchTemplateVersionsResponse/nextToken/text()"os)
    }
  end

  # ResponseLaunchTemplateData. Every member is Required: No -- a template may
  # specify as little as an image ID -- so nothing is cast unconditionally and
  # every sub-structure anchor is optional.
  defp launch_template_data_fields do
    [
      image_id: ~x"./imageId/text()"os,
      instance_type: ~x"./instanceType/text()"os,
      kernel_id: ~x"./kernelId/text()"os,
      ram_disk_id: ~x"./ramDiskId/text()"os,
      key_name: ~x"./keyName/text()"os,
      # Base64 as AWS stores it; decoding here would be this module inventing
      # a representation, and the value is not always valid UTF-8.
      user_data: ~x"./userData/text()"os,
      ebs_optimized: ~x"./ebsOptimized/text()"os,
      disable_api_termination: ~x"./disableApiTermination/text()"os,
      disable_api_stop: ~x"./disableApiStop/text()"os,
      instance_initiated_shutdown_behavior: ~x"./instanceInitiatedShutdownBehavior/text()"os,
      security_group_id_set: ~x"./securityGroupIdSet/item/text()"sl,
      security_group_set: ~x"./securityGroupSet/item/text()"sl,
      iam_instance_profile: [
        ~x"./iamInstanceProfile"o,
        arn: ~x"./arn/text()"os,
        name: ~x"./name/text()"os
      ],
      monitoring: [~x"./monitoring"o, enabled: ~x"./enabled/text()"os],
      placement: [
        ~x"./placement"o,
        availability_zone: ~x"./availabilityZone/text()"os,
        affinity: ~x"./affinity/text()"os,
        group_name: ~x"./groupName/text()"os,
        group_id: ~x"./groupId/text()"os,
        host_id: ~x"./hostId/text()"os,
        tenancy: ~x"./tenancy/text()"os,
        spread_domain: ~x"./spreadDomain/text()"os,
        host_resource_group_arn: ~x"./hostResourceGroupArn/text()"os,
        availability_zone_id: ~x"./availabilityZoneId/text()"os,
        partition_number: ~x"./partitionNumber/text()"oi
      ],
      cpu_options: [
        ~x"./cpuOptions"o,
        core_count: ~x"./coreCount/text()"oi,
        threads_per_core: ~x"./threadsPerCore/text()"oi,
        amd_sev_snp: ~x"./amdSevSnp/text()"os
      ],
      metadata_options: [
        ~x"./metadataOptions"o,
        state: ~x"./state/text()"os,
        http_tokens: ~x"./httpTokens/text()"os,
        http_endpoint: ~x"./httpEndpoint/text()"os,
        http_protocol_ipv6: ~x"./httpProtocolIpv6/text()"os,
        instance_metadata_tags: ~x"./instanceMetadataTags/text()"os,
        http_put_response_hop_limit: ~x"./httpPutResponseHopLimit/text()"oi
      ],
      enclave_options: [~x"./enclaveOptions"o, enabled: ~x"./enabled/text()"os],
      hibernation_options: [~x"./hibernationOptions"o, configured: ~x"./configured/text()"os],
      maintenance_options: [
        ~x"./maintenanceOptions"o,
        auto_recovery: ~x"./autoRecovery/text()"os,
        reboot_migration: ~x"./rebootMigration/text()"os
      ],
      private_dns_name_options: [
        ~x"./privateDnsNameOptions"o,
        hostname_type: ~x"./hostnameType/text()"os,
        enable_resource_name_dns_a_record: ~x"./enableResourceNameDnsARecord/text()"os,
        enable_resource_name_dns_aaaa_record: ~x"./enableResourceNameDnsAAAARecord/text()"os
      ],
      instance_market_options: [
        ~x"./instanceMarketOptions"o,
        market_type: ~x"./marketType/text()"os,
        spot_options: [
          ~x"./spotOptions"o,
          max_price: ~x"./maxPrice/text()"os,
          spot_instance_type: ~x"./spotInstanceType/text()"os,
          block_duration_minutes: ~x"./blockDurationMinutes/text()"oi,
          valid_until: ~x"./validUntil/text()"os,
          instance_interruption_behavior: ~x"./instanceInterruptionBehavior/text()"os
        ]
      ],
      credit_specification: [
        ~x"./creditSpecification"o,
        cpu_credits: ~x"./cpuCredits/text()"os
      ],
      capacity_reservation_specification: [
        ~x"./capacityReservationSpecification"o,
        capacity_reservation_preference: ~x"./capacityReservationPreference/text()"os,
        capacity_reservation_target: [
          ~x"./capacityReservationTarget"o,
          capacity_reservation_id: ~x"./capacityReservationId/text()"os,
          capacity_reservation_resource_group_arn:
            ~x"./capacityReservationResourceGroupArn/text()"os
        ]
      ],
      instance_requirements: [
        ~x"./instanceRequirements"o,
        v_cpu_count: [
          ~x"./vCpuCount"o,
          min: ~x"./min/text()"oi,
          max: ~x"./max/text()"oi
        ],
        memory_mi_b: [~x"./memoryMiB"o, min: ~x"./min/text()"oi, max: ~x"./max/text()"oi],
        cpu_manufacturer_set: ~x"./cpuManufacturerSet/item/text()"sl,
        instance_generation_set: ~x"./instanceGenerationSet/item/text()"sl,
        excluded_instance_type_set: ~x"./excludedInstanceTypeSet/item/text()"sl,
        burstable_performance: ~x"./burstablePerformance/text()"os,
        bare_metal: ~x"./bareMetal/text()"os,
        local_storage: ~x"./localStorage/text()"os
      ],
      block_device_mapping_set: [
        ~x"./blockDeviceMappingSet/item"l,
        device_name: ~x"./deviceName/text()"os,
        virtual_name: ~x"./virtualName/text()"os,
        no_device: ~x"./noDevice/text()"os,
        ebs: [
          ~x"./ebs"o,
          snapshot_id: ~x"./snapshotId/text()"os,
          volume_size: ~x"./volumeSize/text()"oi,
          volume_type: ~x"./volumeType/text()"os,
          iops: ~x"./iops/text()"oi,
          throughput: ~x"./throughput/text()"oi,
          delete_on_termination: ~x"./deleteOnTermination/text()"os,
          encrypted: ~x"./encrypted/text()"os,
          kms_key_id: ~x"./kmsKeyId/text()"os
        ]
      ],
      network_interface_set: [
        ~x"./networkInterfaceSet/item"l,
        network_interface_id: ~x"./networkInterfaceId/text()"os,
        device_index: ~x"./deviceIndex/text()"oi,
        network_card_index: ~x"./networkCardIndex/text()"oi,
        subnet_id: ~x"./subnetId/text()"os,
        description: ~x"./description/text()"os,
        associate_public_ip_address: ~x"./associatePublicIpAddress/text()"os,
        associate_carrier_ip_address: ~x"./associateCarrierIpAddress/text()"os,
        delete_on_termination: ~x"./deleteOnTermination/text()"os,
        interface_type: ~x"./interfaceType/text()"os,
        private_ip_address: ~x"./privateIpAddress/text()"os,
        ipv6_address_count: ~x"./ipv6AddressCount/text()"oi,
        secondary_private_ip_address_count: ~x"./secondaryPrivateIpAddressCount/text()"oi,
        group_set: ~x"./groupSet/item/text()"sl,
        private_ip_addresses_set: [
          ~x"./privateIpAddressesSet/item"l,
          primary: ~x"./primary/text()"os,
          private_ip_address: ~x"./privateIpAddress/text()"os
        ],
        ipv6_addresses_set: [
          ~x"./ipv6AddressesSet/item"l,
          ipv6_address: ~x"./ipv6Address/text()"os,
          is_primary_ipv6: ~x"./isPrimaryIpv6/text()"os
        ]
      ],
      # A TagSpecification nests its own tagSet, so tags live two levels down.
      tag_specification_set: [
        ~x"./tagSpecificationSet/item"l,
        resource_type: ~x"./resourceType/text()"os,
        tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
      ],
      license_set: [
        ~x"./licenseSet/item"l,
        license_configuration_arn: ~x"./licenseConfigurationArn/text()"os
      ],
      elastic_gpu_specification_set: [
        ~x"./elasticGpuSpecificationSet/item"l,
        type: ~x"./type/text()"os
      ]
    ]
  end

  @doc """
  Describes the specified tags for the given resources.

  Returns `%{tag_set: [...], next_token: ...}`, where each tag is
  `%{resource_id:, resource_type:, key:, value:}`.

  ## Options

    * `:filters` - List of `%{name:, values:}` filters. Common filter names:
      `"key"`, `"value"`, `"resource-id"`, `"resource-type"`.

  ## Examples

      AwsSdk.EC2.describe_tags(filters: [%{name: "resource-id", values: ["i-1234567890abcdef0"]}])
      #=> {:ok,
      #=>  %{
      #=>    tag_set: [
      #=>      %{
      #=>        resource_id: "i-1234567890abcdef0",
      #=>        resource_type: "instance",
      #=>        key: "Name",
      #=>        value: "web-1"
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}
  """
  @spec describe_tags(opts :: keyword()) ::
          {:ok, %{tag_set: list(map()), next_token: String.t() | nil}} | {:error, term()}
  def describe_tags(opts \\ []) do
    if sandbox?(opts) do
      sandbox_describe_tags_response(opts)
    else
      do_describe_tags(opts)
    end
  end

  defp do_describe_tags(opts) do
    params = put_filters(%{}, opts[:filters] || [])

    with {:ok, op} <- build_operation("DescribeTags", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      tags =
        xpath(body, ~x"//tagSet/item"l,
          resource_id: ~x"./resourceId/text()"s,
          resource_type: ~x"./resourceType/text()"s,
          key: ~x"./key/text()"s,
          value: ~x"./value/text()"s
        )

      {:ok,
       %{tag_set: tags, next_token: xpath(body, ~x"//DescribeTagsResponse/nextToken/text()"os)}}
    end
  end

  # ---------------------------------------------------------------------------
  # Sandbox delegation
  # ---------------------------------------------------------------------------

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

  defp encode_body(action, params) do
    params
    |> Map.merge(%{"Action" => action, "Version" => @api_version})
    |> URI.encode_query()
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

  # ---------------------------------------------------------------------------
  # Sandbox delegation
  # ---------------------------------------------------------------------------

  defp sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    cfg = AwsSdk.Config.sandbox()
    enabled = Keyword.get(sandbox_opts, :enabled, cfg[:enabled])

    enabled and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    @doc false
    defdelegate sandbox_disabled?, to: AwsSdk.EC2.Sandbox, as: :sandbox_disabled?

    @doc false
    defdelegate sandbox_create_security_group_response(name, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :create_security_group_response

    @doc false
    defdelegate sandbox_describe_security_groups_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_security_groups_response

    @doc false
    defdelegate sandbox_delete_security_group_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :delete_security_group_response

    @doc false
    defdelegate sandbox_authorize_security_group_ingress_response(group_id, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :authorize_security_group_ingress_response

    @doc false
    defdelegate sandbox_revoke_security_group_ingress_response(group_id, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :revoke_security_group_ingress_response

    @doc false
    defdelegate sandbox_authorize_security_group_egress_response(group_id, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :authorize_security_group_egress_response

    @doc false
    defdelegate sandbox_revoke_security_group_egress_response(group_id, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :revoke_security_group_egress_response

    @doc false
    defdelegate sandbox_describe_vpcs_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_vpcs_response

    @doc false
    defdelegate sandbox_describe_subnets_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_subnets_response

    @doc false
    defdelegate sandbox_create_tags_response(resource_ids, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :create_tags_response

    @doc false
    defdelegate sandbox_describe_tags_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_tags_response

    @doc false
    defdelegate sandbox_describe_launch_templates_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_launch_templates_response

    @doc false
    defdelegate sandbox_describe_launch_template_versions_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_launch_template_versions_response

    @doc false
    defdelegate sandbox_describe_instances_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_instances_response

    @doc false
    defdelegate sandbox_describe_images_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_images_response

    @doc false
    defdelegate sandbox_deregister_image_response(image_id, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :deregister_image_response

    @doc false
    defdelegate sandbox_delete_snapshot_response(snapshot_id, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :delete_snapshot_response

    @doc false
    defdelegate sandbox_terminate_instances_response(instance_ids, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :terminate_instances_response

    @doc false
    defdelegate sandbox_get_console_output_response(instance_id, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :get_console_output_response

    @doc false
    defdelegate sandbox_describe_network_acls_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_network_acls_response

    @doc false
    defdelegate sandbox_describe_route_tables_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_route_tables_response

    @doc false
    defdelegate sandbox_describe_key_pairs_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_key_pairs_response

    @doc false
    defdelegate sandbox_delete_key_pair_response(key_name, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :delete_key_pair_response

    @doc false
    defdelegate sandbox_describe_security_group_rules_response(opts),
      to: AwsSdk.EC2.Sandbox,
      as: :describe_security_group_rules_response
  else
    defp sandbox_disabled?, do: true

    defp sandbox_create_security_group_response(_, _), do: raise("sandbox not available")
    defp sandbox_describe_security_groups_response(_), do: raise("sandbox not available")
    defp sandbox_delete_security_group_response(_o), do: raise("sandbox not available")

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
    defp sandbox_describe_launch_templates_response(_), do: raise("sandbox not available")

    defp sandbox_describe_launch_template_versions_response(_),
      do: raise("sandbox not available")

    defp sandbox_describe_instances_response(_), do: raise("sandbox not available")
    defp sandbox_describe_images_response(_), do: raise("sandbox not available")
    defp sandbox_deregister_image_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_snapshot_response(_, _), do: raise("sandbox not available")
    defp sandbox_terminate_instances_response(_, _), do: raise("sandbox not available")
    defp sandbox_get_console_output_response(_, _), do: raise("sandbox not available")
    defp sandbox_describe_network_acls_response(_), do: raise("sandbox not available")
    defp sandbox_describe_route_tables_response(_), do: raise("sandbox not available")
    defp sandbox_describe_key_pairs_response(_), do: raise("sandbox not available")
    defp sandbox_delete_key_pair_response(_, _), do: raise("sandbox not available")

    defp sandbox_describe_security_group_rules_response(_),
      do: raise("sandbox not available")
  end

  # ---------------------------------------------------------------------------
  # Overrides / response handling
  # ---------------------------------------------------------------------------

  @override_keys [:headers, :body, :http, :url]

  defp apply_overrides(op, overrides) do
    Enum.reduce(@override_keys, op, fn key, acc ->
      case Keyword.fetch(overrides, key) do
        {:ok, value} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end
end
