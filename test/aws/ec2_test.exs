defmodule AWS.EC2Test do
  use ExUnit.Case

  alias AWS.EC2
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} = TestCowboyServer.start(fn req -> :cowboy_req.reply(200, req) end)
    on_exit(fn -> TestCowboyServer.stop() end)

    opts = [
      access_key_id: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      region: "us-east-1",
      ec2: [scheme: "http", host: "127.0.0.1", port: port]
    ]

    %{port: port, opts: opts}
  end

  defp reply_xml(req, status, body) do
    :cowboy_req.reply(status, %{"content-type" => "text/xml"}, body, req)
  end

  @images_xml """
  <DescribeImagesResponse xmlns="http://ec2.amazonaws.com/doc/2016-11-15/">
    <imagesSet>
      <item>
        <imageId>ami-111</imageId>
        <name>deployd-web-1.0.0</name>
        <imageState>available</imageState>
        <imageOwnerId>123456789012</imageOwnerId>
        <creationDate>2026-07-01T10:00:00.000Z</creationDate>
        <tagSet>
          <item><key>ReleaseGroup</key><value>deployd</value></item>
          <item><key>ReleaseApp</key><value>web</value></item>
        </tagSet>
        <blockDeviceMapping>
          <item><deviceName>/dev/xvda</deviceName><ebs><snapshotId>snap-aaa</snapshotId></ebs></item>
        </blockDeviceMapping>
      </item>
      <item>
        <imageId>ami-222</imageId>
        <name>instance-store</name>
        <creationDate>2026-06-01T10:00:00.000Z</creationDate>
        <blockDeviceMapping>
          <item><deviceName>/dev/sda1</deviceName></item>
        </blockDeviceMapping>
      </item>
    </imagesSet>
  </DescribeImagesResponse>
  """

  describe "describe_images/1" do
    test "encodes owners and tag filters", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        send(test_pid, {:content_type, :cowboy_req.header("content-type", req)})
        reply_xml(req, 200, @images_xml)
      end)

      assert {:ok, _} =
               EC2.describe_images(
                 opts ++
                   [
                     owners: ["self"],
                     filters: [%{name: "tag:ReleaseGroup", values: ["deployd"]}]
                   ]
               )

      assert_receive {:content_type, "application/x-www-form-urlencoded"}
      assert_receive {:body, body}

      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeImages"
      assert decoded["Version"] === "2016-11-15"
      assert decoded["Owner.1"] === "self"
      assert decoded["Filter.1.Name"] === "tag:ReleaseGroup"
      assert decoded["Filter.1.Value.1"] === "deployd"
    end

    test "drops filters that carry no values", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, @images_xml)
      end)

      assert {:ok, _} =
               EC2.describe_images(
                 opts ++
                   [
                     owners: ["self"],
                     filters: [
                       %{name: "tag:Empty", values: []},
                       %{name: "tag:ReleaseApp", values: ["web"]}
                     ]
                   ]
               )

      assert_receive {:body, body}
      decoded = URI.decode_query(body)

      # The valueless filter is dropped rather than sent as a bare name,
      # which AWS rejects with InvalidParameterValue.
      assert decoded["Filter.1.Name"] === "tag:ReleaseApp"
      assert decoded["Filter.1.Value.1"] === "web"
      refute Map.has_key?(decoded, "Filter.2.Name")
    end

    test "parses tags and block device mappings", %{opts: opts} do
      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, @images_xml) end)

      assert {:ok, %{images: [first, second]}} = EC2.describe_images(opts ++ [owners: ["self"]])

      assert first.image_id === "ami-111"
      assert first.creation_date === "2026-07-01T10:00:00.000Z"
      assert %{key: "ReleaseApp", value: "web"} in first.tags
      assert [%{device_name: "/dev/xvda", snapshot_id: "snap-aaa"}] = first.block_device_mappings

      # An instance-store AMI has no <ebs> child, so there is no snapshot
      # to delete and the id is nil rather than an empty string.
      assert [%{snapshot_id: nil}] = second.block_device_mappings
    end

    test "maps a 4xx to a not_found error", %{opts: opts} do
      TestCowboyServer.set_handler(fn req -> reply_xml(req, 400, "<Response/>") end)

      assert {:error, %ErrorMessage{code: :not_found}} =
               EC2.describe_images(opts ++ [owners: ["self"]])
    end
  end

  describe "deregister_image/2" do
    test "sends the image id and returns an empty map", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})

        reply_xml(
          req,
          200,
          "<DeregisterImageResponse><return>true</return></DeregisterImageResponse>"
        )
      end)

      assert {:ok, %{}} = EC2.deregister_image("ami-111", opts)

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DeregisterImage"
      assert decoded["ImageId"] === "ami-111"
    end
  end

  describe "delete_snapshot/2" do
    test "sends the snapshot id and returns an empty map", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})

        reply_xml(
          req,
          200,
          "<DeleteSnapshotResponse><return>true</return></DeleteSnapshotResponse>"
        )
      end)

      assert {:ok, %{}} = EC2.delete_snapshot("snap-aaa", opts)

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DeleteSnapshot"
      assert decoded["SnapshotId"] === "snap-aaa"
    end
  end

  describe "describe_instances/1" do
    test "encodes instance ids and parses state and public ip", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})

        reply_xml(req, 200, """
        <DescribeInstancesResponse xmlns="http://ec2.amazonaws.com/doc/2016-11-15/">
          <reservationSet><item>
            <reservationId>r-1</reservationId>
            <instancesSet><item>
              <instanceId>i-0abc</instanceId>
              <instanceState><name>running</name></instanceState>
              <ipAddress>203.0.113.10</ipAddress>
            </item></instancesSet>
          </item></reservationSet>
        </DescribeInstancesResponse>
        """)
      end)

      assert {:ok, %{reservations: [%{instances: [instance]}]}} =
               EC2.describe_instances(Keyword.put(opts, :instance_ids, ["i-0abc"]))

      assert instance.instance_id === "i-0abc"
      assert instance.state === "running"
      assert instance.public_ip_address === "203.0.113.10"

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeInstances"
      assert decoded["InstanceId.1"] === "i-0abc"
    end
  end
end
