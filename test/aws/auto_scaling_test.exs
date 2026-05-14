defmodule AWS.AutoScalingTest do
  use ExUnit.Case

  alias AWS.AutoScaling
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} = TestCowboyServer.start(fn req -> :cowboy_req.reply(200, req) end)
    on_exit(fn -> TestCowboyServer.stop() end)

    opts = [
      access_key_id: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      region: "us-east-1",
      auto_scaling: [scheme: "http", host: "127.0.0.1", port: port]
    ]

    %{port: port, opts: opts}
  end

  defp reply_xml(req, status, body) do
    :cowboy_req.reply(status, %{"content-type" => "text/xml"}, body, req)
  end

  defp empty_describe_groups_xml do
    """
    <DescribeAutoScalingGroupsResponse xmlns="https://autoscaling.amazonaws.com/doc/2011-01-01/">
      <DescribeAutoScalingGroupsResult><AutoScalingGroups/></DescribeAutoScalingGroupsResult>
      <ResponseMetadata><RequestId>req-1</RequestId></ResponseMetadata>
    </DescribeAutoScalingGroupsResponse>
    """
  end

  describe "request format" do
    test "encodes form-urlencoded body with Action, Version, and member.N for list params",
         %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        send(test_pid, {:content_type, :cowboy_req.header("content-type", req)})
        reply_xml(req, 200, empty_describe_groups_xml())
      end)

      assert {:ok, _} =
               AutoScaling.describe_auto_scaling_groups(
                 Keyword.put(opts, :auto_scaling_group_names, ["asg-a", "asg-b"])
               )

      assert_receive {:content_type, "application/x-www-form-urlencoded"}
      assert_receive {:body, body}

      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeAutoScalingGroups"
      assert decoded["Version"] === "2011-01-01"
      assert decoded["AutoScalingGroupNames.member.1"] === "asg-a"
      assert decoded["AutoScalingGroupNames.member.2"] === "asg-b"
    end

    test "request is signed with service=autoscaling", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:auth, :cowboy_req.header("authorization", req)})
        reply_xml(req, 200, empty_describe_groups_xml())
      end)

      assert {:ok, _} = AutoScaling.describe_auto_scaling_groups(opts)
      assert_receive {:auth, auth}
      assert is_binary(auth)
      assert auth =~ "/autoscaling/aws4_request"
    end

    test "does not send X-Amz-Target header (Query protocol)", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:target, :cowboy_req.header("x-amz-target", req)})
        reply_xml(req, 200, empty_describe_groups_xml())
      end)

      assert {:ok, _} = AutoScaling.describe_auto_scaling_groups(opts)
      assert_receive {:target, :undefined}
    end
  end

  describe "describe_auto_scaling_groups/1 response parsing" do
    test "parses AutoScalingGroups with nested Instances and AvailabilityZones",
         %{opts: opts} do
      xml = ~s"""
      <DescribeAutoScalingGroupsResponse xmlns="https://autoscaling.amazonaws.com/doc/2011-01-01/">
        <DescribeAutoScalingGroupsResult>
          <AutoScalingGroups>
            <member>
              <AutoScalingGroupName>my-asg</AutoScalingGroupName>
              <AutoScalingGroupARN>arn:aws:autoscaling:us-east-1:123:autoScalingGroup:abc:autoScalingGroupName/my-asg</AutoScalingGroupARN>
              <MinSize>1</MinSize>
              <MaxSize>3</MaxSize>
              <DesiredCapacity>2</DesiredCapacity>
              <DefaultCooldown>300</DefaultCooldown>
              <AvailabilityZones>
                <member>us-east-1a</member>
                <member>us-east-1b</member>
              </AvailabilityZones>
              <HealthCheckType>EC2</HealthCheckType>
              <Instances>
                <member>
                  <InstanceId>i-aaaa</InstanceId>
                  <InstanceType>t3.micro</InstanceType>
                  <AvailabilityZone>us-east-1a</AvailabilityZone>
                  <LifecycleState>InService</LifecycleState>
                  <HealthStatus>Healthy</HealthStatus>
                  <ProtectedFromScaleIn>false</ProtectedFromScaleIn>
                </member>
                <member>
                  <InstanceId>i-bbbb</InstanceId>
                  <InstanceType>t3.micro</InstanceType>
                  <AvailabilityZone>us-east-1b</AvailabilityZone>
                  <LifecycleState>Pending:Wait</LifecycleState>
                  <HealthStatus>Healthy</HealthStatus>
                  <ProtectedFromScaleIn>false</ProtectedFromScaleIn>
                </member>
              </Instances>
              <CreatedTime>2024-01-01T00:00:00Z</CreatedTime>
              <VPCZoneIdentifier>subnet-1,subnet-2</VPCZoneIdentifier>
            </member>
          </AutoScalingGroups>
        </DescribeAutoScalingGroupsResult>
      </DescribeAutoScalingGroupsResponse>
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, xml) end)

      assert {:ok,
              %{
                auto_scaling_groups: [
                  %{
                    auto_scaling_group_name: "my-asg",
                    min_size: 1,
                    max_size: 3,
                    desired_capacity: 2,
                    default_cooldown: 300,
                    availability_zones: ["us-east-1a", "us-east-1b"],
                    health_check_type: "EC2",
                    instances: [
                      %{
                        instance_id: "i-aaaa",
                        lifecycle_state: "InService",
                        protected_from_scale_in: false
                      },
                      %{
                        instance_id: "i-bbbb",
                        lifecycle_state: "Pending:Wait",
                        protected_from_scale_in: false
                      }
                    ],
                    vpc_zone_identifier: "subnet-1,subnet-2"
                  }
                ],
                next_token: nil
              }} = AutoScaling.describe_auto_scaling_groups(opts)
    end

    test "empty AutoScalingGroups produces empty list", %{opts: opts} do
      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, empty_describe_groups_xml()) end)

      assert {:ok, %{auto_scaling_groups: [], next_token: nil}} =
               AutoScaling.describe_auto_scaling_groups(opts)
    end
  end

  describe "describe_auto_scaling_instances/1" do
    test "encodes InstanceIds.member.N and parses AutoScalingInstances", %{opts: opts} do
      test_pid = self()

      xml = ~s"""
      <DescribeAutoScalingInstancesResponse xmlns="https://autoscaling.amazonaws.com/doc/2011-01-01/">
        <DescribeAutoScalingInstancesResult>
          <AutoScalingInstances>
            <member>
              <InstanceId>i-aaaa</InstanceId>
              <AutoScalingGroupName>my-asg</AutoScalingGroupName>
              <AvailabilityZone>us-east-1a</AvailabilityZone>
              <LifecycleState>InService</LifecycleState>
              <HealthStatus>HEALTHY</HealthStatus>
              <InstanceType>t3.micro</InstanceType>
              <ProtectedFromScaleIn>false</ProtectedFromScaleIn>
            </member>
          </AutoScalingInstances>
        </DescribeAutoScalingInstancesResult>
      </DescribeAutoScalingInstancesResponse>
      """

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, xml)
      end)

      assert {:ok,
              %{
                auto_scaling_instances: [
                  %{
                    instance_id: "i-aaaa",
                    auto_scaling_group_name: "my-asg",
                    lifecycle_state: "InService",
                    protected_from_scale_in: false
                  }
                ],
                next_token: nil
              }} =
               AutoScaling.describe_auto_scaling_instances(
                 Keyword.put(opts, :instance_ids, ["i-aaaa", "i-bbbb"])
               )

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeAutoScalingInstances"
      assert decoded["InstanceIds.member.1"] === "i-aaaa"
      assert decoded["InstanceIds.member.2"] === "i-bbbb"
    end
  end

  describe "describe_instance_refreshes/2" do
    test "encodes AutoScalingGroupName and parses InstanceRefreshes", %{opts: opts} do
      test_pid = self()

      xml = ~s"""
      <DescribeInstanceRefreshesResponse xmlns="https://autoscaling.amazonaws.com/doc/2011-01-01/">
        <DescribeInstanceRefreshesResult>
          <InstanceRefreshes>
            <member>
              <InstanceRefreshId>refresh-1</InstanceRefreshId>
              <AutoScalingGroupName>my-asg</AutoScalingGroupName>
              <Status>InProgress</Status>
              <PercentageComplete>50</PercentageComplete>
              <InstancesToUpdate>0</InstancesToUpdate>
              <StartTime>2024-01-01T00:00:00Z</StartTime>
              <Preferences>{}</Preferences>
            </member>
          </InstanceRefreshes>
        </DescribeInstanceRefreshesResult>
      </DescribeInstanceRefreshesResponse>
      """

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, xml)
      end)

      assert {:ok,
              %{
                instance_refreshes: [
                  %{
                    instance_refresh_id: "refresh-1",
                    auto_scaling_group_name: "my-asg",
                    status: "InProgress",
                    percentage_complete: 50,
                    instances_to_update: 0,
                    start_time: "2024-01-01T00:00:00Z"
                  }
                ],
                next_token: nil
              }} = AutoScaling.describe_instance_refreshes("my-asg", opts)

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeInstanceRefreshes"
      assert decoded["AutoScalingGroupName"] === "my-asg"
    end
  end

  describe "start_instance_refresh/2" do
    test "encodes ASG name and parses InstanceRefreshId", %{opts: opts} do
      xml = ~s"""
      <StartInstanceRefreshResponse xmlns="https://autoscaling.amazonaws.com/doc/2011-01-01/">
        <StartInstanceRefreshResult>
          <InstanceRefreshId>refresh-1</InstanceRefreshId>
        </StartInstanceRefreshResult>
      </StartInstanceRefreshResponse>
      """

      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, xml)
      end)

      assert {:ok, %{instance_refresh_id: "refresh-1"}} =
               AutoScaling.start_instance_refresh("my-asg", opts)

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "StartInstanceRefresh"
      assert decoded["AutoScalingGroupName"] === "my-asg"
    end

    test "flattens arbitrary :preferences map (any AWS field passes through)",
         %{opts: opts} do
      xml = ~s"""
      <StartInstanceRefreshResponse>
        <StartInstanceRefreshResult><InstanceRefreshId>r1</InstanceRefreshId></StartInstanceRefreshResult>
      </StartInstanceRefreshResponse>
      """

      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, xml)
      end)

      preferences = %{
        min_healthy_percentage: 90,
        instance_warmup: 300,
        skip_matching: true,
        checkpoint_percentages: [25, 50, 100]
      }

      assert {:ok, %{instance_refresh_id: "r1"}} =
               AutoScaling.start_instance_refresh(
                 "my-asg",
                 Keyword.merge(opts, strategy: "Rolling", preferences: preferences)
               )

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Strategy"] === "Rolling"
      assert decoded["Preferences.MinHealthyPercentage"] === "90"
      assert decoded["Preferences.InstanceWarmup"] === "300"
      assert decoded["Preferences.SkipMatching"] === "true"
      assert decoded["Preferences.CheckpointPercentages.member.1"] === "25"
      assert decoded["Preferences.CheckpointPercentages.member.2"] === "50"
      assert decoded["Preferences.CheckpointPercentages.member.3"] === "100"
    end
  end

  describe "cancel_instance_refresh/2" do
    test "parses InstanceRefreshId", %{opts: opts} do
      xml = ~s"""
      <CancelInstanceRefreshResponse>
        <CancelInstanceRefreshResult><InstanceRefreshId>refresh-2</InstanceRefreshId></CancelInstanceRefreshResult>
      </CancelInstanceRefreshResponse>
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, xml) end)

      assert {:ok, %{instance_refresh_id: "refresh-2"}} =
               AutoScaling.cancel_instance_refresh("my-asg", opts)
    end
  end

  describe "rollback_instance_refresh/2" do
    test "parses InstanceRefreshId", %{opts: opts} do
      xml = ~s"""
      <RollbackInstanceRefreshResponse>
        <RollbackInstanceRefreshResult><InstanceRefreshId>refresh-3</InstanceRefreshId></RollbackInstanceRefreshResult>
      </RollbackInstanceRefreshResponse>
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, xml) end)

      assert {:ok, %{instance_refresh_id: "refresh-3"}} =
               AutoScaling.rollback_instance_refresh("my-asg", opts)
    end
  end

  describe "complete_lifecycle_action/1" do
    test "encodes hook+asg+result and returns empty success map", %{opts: opts} do
      xml = ~s"""
      <CompleteLifecycleActionResponse>
        <CompleteLifecycleActionResult/>
      </CompleteLifecycleActionResponse>
      """

      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, xml)
      end)

      assert {:ok, %{}} =
               AutoScaling.complete_lifecycle_action(
                 [
                   lifecycle_hook_name: "my-hook",
                   auto_scaling_group_name: "my-asg",
                   lifecycle_action_result: "CONTINUE",
                   instance_id: "i-aaaa"
                 ] ++ opts
               )

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "CompleteLifecycleAction"
      assert decoded["LifecycleHookName"] === "my-hook"
      assert decoded["AutoScalingGroupName"] === "my-asg"
      assert decoded["LifecycleActionResult"] === "CONTINUE"
      assert decoded["InstanceId"] === "i-aaaa"
    end

    test "raises ArgumentError when required keys are missing", %{opts: opts} do
      assert_raise ArgumentError, ~r/lifecycle_action_result/, fn ->
        AutoScaling.complete_lifecycle_action(
          [lifecycle_hook_name: "h", auto_scaling_group_name: "a"] ++ opts
        )
      end
    end
  end

  describe "record_lifecycle_action_heartbeat/1" do
    test "encodes hook+asg and returns empty success map", %{opts: opts} do
      xml = ~s"""
      <RecordLifecycleActionHeartbeatResponse>
        <RecordLifecycleActionHeartbeatResult/>
      </RecordLifecycleActionHeartbeatResponse>
      """

      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, xml)
      end)

      assert {:ok, %{}} =
               AutoScaling.record_lifecycle_action_heartbeat(
                 [
                   lifecycle_hook_name: "my-hook",
                   auto_scaling_group_name: "my-asg",
                   lifecycle_action_token: "tok-1"
                 ] ++ opts
               )

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "RecordLifecycleActionHeartbeat"
      assert decoded["LifecycleHookName"] === "my-hook"
      assert decoded["LifecycleActionToken"] === "tok-1"
    end
  end

  describe "set_instance_health/3" do
    test "encodes InstanceId and HealthStatus", %{opts: opts} do
      xml = ~s"""
      <SetInstanceHealthResponse><SetInstanceHealthResult/></SetInstanceHealthResponse>
      """

      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, xml)
      end)

      assert {:ok, %{}} = AutoScaling.set_instance_health("i-aaaa", "Unhealthy", opts)

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "SetInstanceHealth"
      assert decoded["InstanceId"] === "i-aaaa"
      assert decoded["HealthStatus"] === "Unhealthy"
    end
  end

  describe "terminate_instance_in_auto_scaling_group/3" do
    test "encodes InstanceId+ShouldDecrement and parses Activity", %{opts: opts} do
      xml = ~s"""
      <TerminateInstanceInAutoScalingGroupResponse>
        <TerminateInstanceInAutoScalingGroupResult>
          <Activity>
            <ActivityId>act-1</ActivityId>
            <AutoScalingGroupName>my-asg</AutoScalingGroupName>
            <Cause>user requested</Cause>
            <Description>Terminating EC2 instance: i-aaaa</Description>
            <Progress>50</Progress>
            <StatusCode>InProgress</StatusCode>
            <StartTime>2024-01-01T00:00:00Z</StartTime>
          </Activity>
        </TerminateInstanceInAutoScalingGroupResult>
      </TerminateInstanceInAutoScalingGroupResponse>
      """

      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, xml)
      end)

      assert {:ok,
              %{
                activity: %{
                  activity_id: "act-1",
                  status_code: "InProgress",
                  progress: 50,
                  cause: "user requested"
                }
              }} =
               AutoScaling.terminate_instance_in_auto_scaling_group("i-aaaa", true, opts)

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "TerminateInstanceInAutoScalingGroup"
      assert decoded["InstanceId"] === "i-aaaa"
      assert decoded["ShouldDecrementDesiredCapacity"] === "true"
    end
  end

  describe "error responses" do
    test "4xx maps to ErrorMessage with :not_found code", %{opts: opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_xml(req, 404, """
        <ErrorResponse><Error><Code>ValidationError</Code><Message>nope</Message></Error></ErrorResponse>
        """)
      end)

      assert {:error, %ErrorMessage{code: :not_found}} =
               AutoScaling.describe_auto_scaling_groups(opts)
    end

    test "5xx maps to ErrorMessage with :service_unavailable code", %{opts: opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_xml(req, 500, """
        <ErrorResponse><Error><Code>InternalFailure</Code><Message>boom</Message></Error></ErrorResponse>
        """)
      end)

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               AutoScaling.describe_auto_scaling_groups(opts)
    end
  end

  describe "set_desired_capacity/3" do
    test "encodes ASG name and DesiredCapacity", %{opts: opts} do
      xml = ~s"""
      <SetDesiredCapacityResponse><SetDesiredCapacityResult/></SetDesiredCapacityResponse>
      """

      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, xml)
      end)

      assert {:ok, %{}} = AutoScaling.set_desired_capacity("my-asg", 5, opts)

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "SetDesiredCapacity"
      assert decoded["AutoScalingGroupName"] === "my-asg"
      assert decoded["DesiredCapacity"] === "5"
    end
  end
end
