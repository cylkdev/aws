defmodule AWS.EC2.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.EC2
  alias AWS.EC2.Sandbox

  @sandbox_opts [sandbox: [enabled: true]]

  # Security Groups

  describe "create_security_group/4" do
    test "returns mocked success" do
      Sandbox.set_create_security_group_responses([
        {"web", fn -> {:ok, %{group_id: "sg-1"}} end}
      ])

      assert {:ok, %{group_id: "sg-1"}} =
               EC2.create_security_group("web", "web tier", "vpc-1", @sandbox_opts)
    end
  end

  describe "describe_security_groups/1" do
    test "returns mocked list" do
      Sandbox.set_describe_security_groups_responses([
        fn -> {:ok, %{security_groups: [%{group_id: "sg-1", group_name: "web"}]}} end
      ])

      assert {:ok, %{security_groups: [%{group_id: "sg-1"}]}} =
               EC2.describe_security_groups(
                 Keyword.merge(@sandbox_opts,
                   filters: [%{name: "vpc-id", values: ["vpc-1"]}]
                 )
               )
    end
  end

  describe "delete_security_group/2" do
    test "returns mocked success" do
      Sandbox.set_delete_security_group_responses([
        {"sg-1", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = EC2.delete_security_group("sg-1", @sandbox_opts)
    end
  end

  describe "authorize_security_group_ingress/3" do
    test "returns mocked success" do
      Sandbox.set_authorize_security_group_ingress_responses([
        {"sg-1", fn -> {:ok, %{}} end}
      ])

      rules = [
        %{
          protocol: "tcp",
          from_port: 443,
          to_port: 443,
          ip_ranges: [%{cidr_ip: "0.0.0.0/0"}]
        }
      ]

      assert {:ok, %{}} =
               EC2.authorize_security_group_ingress("sg-1", rules, @sandbox_opts)
    end
  end

  describe "revoke_security_group_ingress/3" do
    test "returns mocked success" do
      Sandbox.set_revoke_security_group_ingress_responses([
        {"sg-1", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = EC2.revoke_security_group_ingress("sg-1", [], @sandbox_opts)
    end
  end

  describe "authorize_security_group_egress/3" do
    test "returns mocked success" do
      Sandbox.set_authorize_security_group_egress_responses([
        {"sg-1", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = EC2.authorize_security_group_egress("sg-1", [], @sandbox_opts)
    end
  end

  describe "revoke_security_group_egress/3" do
    test "returns mocked success" do
      Sandbox.set_revoke_security_group_egress_responses([
        {"sg-1", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = EC2.revoke_security_group_egress("sg-1", [], @sandbox_opts)
    end
  end

  # VPCs / Subnets

  describe "describe_vpcs/1" do
    test "returns mocked list" do
      Sandbox.set_describe_vpcs_responses([
        fn ->
          {:ok, %{vpcs: [%{vpc_id: "vpc-1", cidr_block: "10.0.0.0/16", is_default: true}]}}
        end
      ])

      assert {:ok, %{vpcs: [%{vpc_id: "vpc-1", is_default: true}]}} =
               EC2.describe_vpcs(@sandbox_opts)
    end
  end

  describe "describe_subnets/1" do
    test "returns mocked list" do
      Sandbox.set_describe_subnets_responses([
        fn ->
          {:ok, %{subnets: [%{subnet_id: "subnet-1", vpc_id: "vpc-1"}]}}
        end
      ])

      assert {:ok, %{subnets: [%{subnet_id: "subnet-1"}]}} =
               EC2.describe_subnets(
                 Keyword.merge(@sandbox_opts, filters: [%{name: "vpc-id", values: ["vpc-1"]}])
               )
    end
  end

  # Tags

  describe "create_tags/3" do
    test "returns mocked success" do
      Sandbox.set_create_tags_responses([
        {"i-1", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} =
               EC2.create_tags(
                 ["i-1"],
                 [%{key: "Name", value: "web-1"}, {"Env", "prod"}],
                 @sandbox_opts
               )
    end
  end

  # Regex matching

  describe "regex matching" do
    test "matches security group name by regex" do
      Sandbox.set_create_security_group_responses([
        {~r/^web-/, fn -> {:ok, %{group_id: "sg-matched"}} end}
      ])

      assert {:ok, %{group_id: "sg-matched"}} =
               EC2.create_security_group("web-prod", "desc", "vpc-1", @sandbox_opts)
    end
  end
end
