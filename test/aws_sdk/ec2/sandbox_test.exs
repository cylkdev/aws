defmodule AwsSdk.EC2.SandboxTest do
  use ExUnit.Case, async: true

  alias AwsSdk.EC2
  alias AwsSdk.EC2.Sandbox

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
        fn -> {:ok, %{security_group_info: [%{group_id: "sg-1", group_name: "web"}]}} end
      ])

      assert {:ok, %{security_group_info: [%{group_id: "sg-1", group_name: "web"}]}} =
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
          {:ok, %{vpc_set: [%{vpc_id: "vpc-1", cidr_block: "10.0.0.0/16", is_default: true}]}}
        end
      ])

      assert {:ok, %{vpc_set: [%{vpc_id: "vpc-1", cidr_block: "10.0.0.0/16", is_default: true}]}} =
               EC2.describe_vpcs(sandbox: [enabled: true])
    end
  end

  describe "describe_subnets/1" do
    test "returns the registered subnets" do
      Sandbox.set_describe_subnets_responses([
        fn -> {:ok, %{subnet_set: [%{subnet_id: "subnet-1", vpc_id: "vpc-1"}]}} end
      ])

      assert {:ok, %{subnet_set: [%{subnet_id: "subnet-1", vpc_id: "vpc-1"}]}} =
               EC2.describe_subnets(sandbox: [enabled: true])
    end
  end

  describe "describe_instances/1" do
    test "returns the registered reservations" do
      Sandbox.set_describe_instances_responses([
        fn -> {:ok, %{reservation_set: [%{instances_set: [%{instance_id: "i-1"}]}]}} end
      ])

      assert {:ok, %{reservation_set: [%{instances_set: [%{instance_id: "i-1"}]}]}} =
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
        fn -> {:ok, %{tag_set: [%{key: "Name", value: "web-1", resource_id: "i-1"}]}} end
      ])

      assert {:ok, %{tag_set: [%{key: "Name", value: "web-1", resource_id: "i-1"}]}} =
               EC2.describe_tags(sandbox: [enabled: true])
    end
  end

  describe "describe_images/1" do
    test "returns the registered images" do
      Sandbox.set_describe_images_responses([
        fn ->
          {:ok,
           %{
             images_set: [
               %{
                 image_id: "ami-111",
                 block_device_mapping: [
                   %{device_name: "/dev/xvda", ebs: %{snapshot_id: "snap-aaa"}}
                 ]
               }
             ]
           }}
        end
      ])

      assert {:ok,
              %{
                images_set: [
                  %{
                    image_id: "ami-111",
                    block_device_mapping: [
                      %{device_name: "/dev/xvda", ebs: %{snapshot_id: "snap-aaa"}}
                    ]
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

  describe "describe_launch_templates/1" do
    test "returns the registered launch templates" do
      Sandbox.set_describe_launch_templates_responses([
        fn ->
          {:ok,
           %{
             launch_templates: [
               %{
                 launch_template_id: "lt-1",
                 launch_template_name: "web",
                 default_version_number: 1,
                 latest_version_number: 3
               }
             ],
             next_token: nil
           }}
        end
      ])

      assert {:ok, %{launch_templates: [%{launch_template_id: "lt-1"}]}} =
               EC2.describe_launch_templates(sandbox: [enabled: true])
    end
  end

  describe "describe_launch_template_versions/1" do
    test "returns the registered versions with their template data" do
      Sandbox.set_describe_launch_template_versions_responses([
        fn ->
          {:ok,
           %{
             launch_template_versions: [
               %{
                 launch_template_id: "lt-1",
                 version_number: 3,
                 launch_template_data: %{
                   image_id: "ami-1",
                   instance_type: "t3.micro",
                   placement: %{group_name: "g"}
                 }
               }
             ],
             next_token: nil
           }}
        end
      ])

      assert {:ok,
              %{
                launch_template_versions: [
                  %{version_number: 3, launch_template_data: %{image_id: "ami-1"}}
                ]
              }} =
               EC2.describe_launch_template_versions(
                 launch_template_id: "lt-1",
                 sandbox: [enabled: true]
               )
    end
  end

  describe "terminate_instances/2" do
    test "returns the registered state changes" do
      Sandbox.set_terminate_instances_responses([
        fn ->
          {:ok,
           %{
             instances_set: [
               %{
                 instance_id: "i-1",
                 current_state: %{code: 32, name: "shutting-down"},
                 previous_state: %{code: 16, name: "running"}
               }
             ]
           }}
        end
      ])

      assert {:ok, %{instances_set: [%{instance_id: "i-1"}]}} =
               EC2.terminate_instances(["i-1"], sandbox: [enabled: true])
    end
  end

  describe "get_console_output/2" do
    test "keys off the instance id" do
      Sandbox.set_get_console_output_responses([
        {"i-1", fn -> {:ok, %{instance_id: "i-1", timestamp: nil, output: "boot ok\n"}} end}
      ])

      assert {:ok, %{output: "boot ok\n"}} =
               EC2.get_console_output("i-1", sandbox: [enabled: true])
    end
  end

  describe "describe_network_acls/1" do
    test "returns the registered ACLs" do
      Sandbox.set_describe_network_acls_responses([
        fn -> {:ok, %{network_acl_set: [%{network_acl_id: "acl-1"}], next_token: nil}} end
      ])

      assert {:ok, %{network_acl_set: [%{network_acl_id: "acl-1"}]}} =
               EC2.describe_network_acls(sandbox: [enabled: true])
    end
  end
end
