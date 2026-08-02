defmodule AWS.EC2.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.EC2
  alias AWS.EC2.Sandbox

  describe "create_security_group/4" do
    test "returns the response registered for the group name" do
      Sandbox.set_create_security_group_responses([{"web", fn -> {:ok, %{group_id: "sg-1"}} end}])

      assert {:ok, %{group_id: "sg-1"}} =
               EC2.create_security_group("web", "web tier", "vpc-1", sandbox: [enabled: true])
    end

    test "matches the group name by regex" do
      Sandbox.set_create_security_group_responses([
        {~r/^web-/, fn -> {:ok, %{group_id: "sg-matched"}} end}
      ])

      assert {:ok, %{group_id: "sg-matched"}} =
               EC2.create_security_group("web-prod", "desc", "vpc-1", sandbox: [enabled: true])
    end
  end

  describe "describe_security_groups/1" do
    test "returns the registered groups" do
      Sandbox.set_describe_security_groups_responses([
        fn -> {:ok, %{security_groups: [%{group_id: "sg-1", group_name: "web"}]}} end
      ])

      assert {:ok, %{security_groups: [%{group_id: "sg-1", group_name: "web"}]}} =
               EC2.describe_security_groups(sandbox: [enabled: true])
    end
  end

  describe "delete_security_group/1" do
    test "returns the registered response" do
      Sandbox.set_delete_security_group_responses([fn -> {:ok, %{}} end])

      assert {:ok, %{}} = EC2.delete_security_group(group_id: "sg-1", sandbox: [enabled: true])
    end
  end

  describe "authorize_security_group_ingress/3" do
    test "returns the response registered for the group id" do
      Sandbox.set_authorize_security_group_ingress_responses([{"sg-1", fn -> {:ok, %{}} end}])

      assert {:ok, %{}} =
               EC2.authorize_security_group_ingress(
                 "sg-1",
                 [%{protocol: "tcp", from_port: 443, to_port: 443}],
                 sandbox: [enabled: true]
               )
    end
  end

  describe "revoke_security_group_ingress/3" do
    test "returns the response registered for the group id" do
      Sandbox.set_revoke_security_group_ingress_responses([{"sg-1", fn -> {:ok, %{}} end}])

      assert {:ok, %{}} =
               EC2.revoke_security_group_ingress(
                 "sg-1",
                 [%{protocol: "tcp", from_port: 443, to_port: 443}],
                 sandbox: [enabled: true]
               )
    end
  end

  describe "authorize_security_group_egress/3" do
    test "returns the response registered for the group id" do
      Sandbox.set_authorize_security_group_egress_responses([{"sg-1", fn -> {:ok, %{}} end}])

      assert {:ok, %{}} =
               EC2.authorize_security_group_egress(
                 "sg-1",
                 [%{protocol: "tcp", from_port: 443, to_port: 443}],
                 sandbox: [enabled: true]
               )
    end
  end

  describe "revoke_security_group_egress/3" do
    test "returns the response registered for the group id" do
      Sandbox.set_revoke_security_group_egress_responses([{"sg-1", fn -> {:ok, %{}} end}])

      assert {:ok, %{}} =
               EC2.revoke_security_group_egress(
                 "sg-1",
                 [%{protocol: "tcp", from_port: 443, to_port: 443}],
                 sandbox: [enabled: true]
               )
    end
  end

  describe "describe_vpcs/1" do
    test "returns the registered vpcs" do
      Sandbox.set_describe_vpcs_responses([
        fn ->
          {:ok, %{vpcs: [%{vpc_id: "vpc-1", cidr_block: "10.0.0.0/16", is_default: true}]}}
        end
      ])

      assert {:ok, %{vpcs: [%{vpc_id: "vpc-1", cidr_block: "10.0.0.0/16", is_default: true}]}} =
               EC2.describe_vpcs(sandbox: [enabled: true])
    end
  end

  describe "describe_subnets/1" do
    test "returns the registered subnets" do
      Sandbox.set_describe_subnets_responses([
        fn -> {:ok, %{subnets: [%{subnet_id: "subnet-1", vpc_id: "vpc-1"}]}} end
      ])

      assert {:ok, %{subnets: [%{subnet_id: "subnet-1", vpc_id: "vpc-1"}]}} =
               EC2.describe_subnets(sandbox: [enabled: true])
    end
  end

  describe "describe_instances/1" do
    test "returns the registered reservations" do
      Sandbox.set_describe_instances_responses([
        fn -> {:ok, %{reservations: [%{instances: [%{instance_id: "i-1"}]}]}} end
      ])

      assert {:ok, %{reservations: [%{instances: [%{instance_id: "i-1"}]}]}} =
               EC2.describe_instances(sandbox: [enabled: true])
    end
  end

  describe "create_tags/3" do
    test "returns the response registered for the first resource id" do
      Sandbox.set_create_tags_responses([{"i-1", fn -> {:ok, %{}} end}])

      assert {:ok, %{}} =
               EC2.create_tags(["i-1"], [%{key: "Name", value: "web-1"}],
                 sandbox: [enabled: true]
               )
    end
  end

  describe "describe_tags/1" do
    test "returns the registered tags" do
      Sandbox.set_describe_tags_responses([
        fn -> {:ok, %{tags: [%{key: "Name", value: "web-1", resource_id: "i-1"}]}} end
      ])

      assert {:ok, %{tags: [%{key: "Name", value: "web-1", resource_id: "i-1"}]}} =
               EC2.describe_tags(sandbox: [enabled: true])
    end
  end

  describe "describe_images/1" do
    test "returns the registered images" do
      Sandbox.set_describe_images_responses([
        fn ->
          {:ok,
           %{
             images: [
               %{
                 image_id: "ami-111",
                 block_device_mappings: [%{device_name: "/dev/xvda", snapshot_id: "snap-aaa"}]
               }
             ]
           }}
        end
      ])

      assert {:ok,
              %{
                images: [
                  %{
                    image_id: "ami-111",
                    block_device_mappings: [%{device_name: "/dev/xvda", snapshot_id: "snap-aaa"}]
                  }
                ]
              }} = EC2.describe_images(sandbox: [enabled: true])
    end
  end

  describe "deregister_image/2" do
    test "returns the response registered for the image id" do
      Sandbox.set_deregister_image_responses([{"ami-111", fn -> {:ok, %{}} end}])

      assert {:ok, %{}} = EC2.deregister_image("ami-111", sandbox: [enabled: true])
    end
  end

  describe "delete_snapshot/2" do
    test "returns the response registered for the snapshot id" do
      Sandbox.set_delete_snapshot_responses([{"snap-aaa", fn -> {:ok, %{}} end}])

      assert {:ok, %{}} = EC2.delete_snapshot("snap-aaa", sandbox: [enabled: true])
    end
  end
end
