defmodule AWS.ConformanceTest do
  @moduledoc """
  Regression tests for the conformance defects found by auditing this library
  against the live AWS API references.

  Everything here is a pure function, so these assert on the exact bytes the
  library would put on the wire without standing up a transport.
  """

  use ExUnit.Case, async: true

  test "a caller-supplied host is signed once, not twice" do
    headers =
      AWS.Signer.sign(
        :put,
        "https://bucket.s3.amazonaws.com/k",
        [{"host", "bucket.s3.amazonaws.com"}, {"content-type", "text/plain"}],
        "body",
        %{
          access_key_id: "AK",
          secret_access_key: "SK",
          region: "us-east-1",
          service: "s3",
          now: DateTime.utc_now()
        }
      )

    authorization = headers |> Enum.find(fn {k, _} -> k == "authorization" end) |> elem(1)
    signed = Regex.run(~r/SignedHeaders=([^,]+)/, authorization) |> Enum.at(1)

    assert Enum.count(String.split(signed, ";"), &(&1 == "host")) == 1
    assert Enum.count(headers, fn {k, _} -> k == "host" end) == 1
  end

  test "a caller-supplied x-amz-date is signed once, not twice" do
    headers =
      AWS.Signer.sign(
        :get,
        "https://bucket.s3.amazonaws.com/k",
        [{"x-amz-date", "19700101T000000Z"}],
        "",
        %{
          access_key_id: "AK",
          secret_access_key: "SK",
          region: "us-east-1",
          service: "s3",
          now: DateTime.utc_now()
        }
      )

    authorization = headers |> Enum.find(fn {k, _} -> k == "authorization" end) |> elem(1)
    signed = Regex.run(~r/SignedHeaders=([^,]+)/, authorization) |> Enum.at(1)

    assert Enum.count(String.split(signed, ";"), &(&1 == "x-amz-date")) == 1
    assert Enum.count(headers, fn {k, _} -> k == "x-amz-date" end) == 1
  end

  test "put_bucket_encryption emits a real SSEAlgorithm when none is given" do
    xml = AWS.S3.XMLBuilder.build_bucket_encryption([])

    assert xml =~ "<SSEAlgorithm>AES256</SSEAlgorithm>"
    refute xml =~ "<SSEAlgorithm></SSEAlgorithm>"
  end

  test "a lifecycle rule without :status defaults to Enabled instead of raising" do
    xml = AWS.S3.XMLBuilder.build_lifecycle_configuration([%{id: "r", expiration: %{days: 1}}])

    assert xml =~ "<Status>Enabled</Status>"
  end

  test "put_public_access_block emits only the flags supplied" do
    xml = AWS.S3.XMLBuilder.build_public_access_block(block_public_acls: true)

    assert xml =~ "<BlockPublicAcls>true</BlockPublicAcls>"
    refute xml =~ "IgnorePublicAcls"
    refute xml =~ "BlockPublicPolicy"
    refute xml =~ "RestrictPublicBuckets"
  end

  test "a 200 response carrying an Error body is not reported as success" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Error><Code>InternalError</Code><Message>We encountered an internal error.</Message><RequestId>abc</RequestId></Error>
    """

    assert {:error, %ErrorMessage{details: details}} =
             AWS.S3.XMLParser.parse_complete_multipart(xml)

    assert details.code == "InternalError"

    assert {:error, %ErrorMessage{}} = AWS.S3.XMLParser.parse_copy_object_result(xml)
  end

  test "a successful CompleteMultipartUpload body still parses" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <CompleteMultipartUploadResult><Location>https://x/k</Location><Bucket>b</Bucket><Key>k</Key><ETag>"e"</ETag></CompleteMultipartUploadResult>
    """

    assert %{bucket: "b", key: "k"} = AWS.S3.XMLParser.parse_complete_multipart(xml)
  end

  test "an ini value containing # is not truncated" do
    parsed =
      AWS.Credentials.INI.parse("""
      [p]
      secret = abc#def
      url = https://example.com/x#fragment
      commented = value # trailing comment
      """)

    assert parsed["p"]["secret"] == "abc#def"
    assert parsed["p"]["url"] == "https://example.com/x#fragment"
    assert parsed["p"]["commented"] == "value"
  end

  test "a whole-line ini comment is still ignored" do
    parsed =
      AWS.Credentials.INI.parse("""
      [p]
      # this line is a comment
      key = value
      """)

    assert parsed["p"] == %{"key" => "value"}
  end

  test "Organizations ignores a caller region and uses the global endpoint" do
    {:ok, op} =
      AWS.Organizations.build_operation("ListRoots", %{},
        access_key_id: "AK",
        secret_access_key: "SK",
        region: "eu-west-1"
      )

    assert op.url == "https://organizations.us-east-1.amazonaws.com/"
    assert op.region == "us-east-1"
  end

  test "Organizations stays inside the GovCloud partition" do
    {:ok, op} =
      AWS.Organizations.build_operation("ListRoots", %{},
        access_key_id: "AK",
        secret_access_key: "SK",
        region: "us-gov-east-1"
      )

    assert op.url == "https://organizations.us-gov-west-1.amazonaws.com/"
    assert op.region == "us-gov-west-1"
  end

  test "presigned POST form fields keep their literal AWS names" do
    {:ok, result} =
      AWS.S3.presign_post("b", "k.txt",
        access_key_id: "AK",
        secret_access_key: "SK",
        region: "us-east-1"
      )

    keys = Map.keys(result.fields)

    assert "policy" in keys
    assert "x-amz-algorithm" in keys
    assert "x-amz-credential" in keys
    assert "x-amz-signature" in keys
    refute Enum.any?(keys, &is_atom/1)
  end

  test "an S3 object key with reserved characters signs the path it sends" do
    {:ok, config} =
      AWS.S3.resolve_config(
        access_key_id: "AK",
        secret_access_key: "SK",
        region: "us-east-1"
      )

    url = AWS.S3.build_url(config, "bucket", "my file+a:b#c.txt", %{})

    # encode_key/1 applies AWS's UriEncode, so the signer can sign the path
    # verbatim and still match the wire.
    assert URI.parse(url).path == "/my%20file%2Ba%3Ab%23c.txt"
  end

  test "target health surfaces the reason code that distinguishes ELB faults from target faults" do
    xml = """
    <DescribeTargetHealthResponse><DescribeTargetHealthResult><TargetHealthDescriptions>
    <member><Target><Id>i-abc</Id><Port>80</Port><AvailabilityZone>us-east-1a</AvailabilityZone></Target>
    <HealthCheckPort>80</HealthCheckPort>
    <TargetHealth><State>unhealthy</State><Reason>Elb.InternalError</Reason>
    <Description>Health checks failed due to an internal error</Description></TargetHealth></member>
    </TargetHealthDescriptions></DescribeTargetHealthResult></DescribeTargetHealthResponse>
    """

    %{target_health_descriptions: [target]} =
      AWS.ElasticLoadBalancingV2.parse_describe_target_health(xml)

    assert target.state == "unhealthy"
    assert target.reason == "Elb.InternalError"
    assert target.description == "Health checks failed due to an internal error"
    assert target.availability_zone == "us-east-1a"
    assert target.health_check_port == "80"
  end

  test "a target group health check port keeps its non-numeric value" do
    xml = """
    <DescribeTargetGroupsResponse><DescribeTargetGroupsResult><TargetGroups><member>
    <TargetGroupArn>arn:tg/1</TargetGroupArn><TargetGroupName>web</TargetGroupName>
    <HealthCheckPort>traffic-port</HealthCheckPort><HealthCheckPath>/health</HealthCheckPath>
    <Matcher><HttpCode>200</HttpCode></Matcher>
    <LoadBalancerArns><member>arn:lb/1</member></LoadBalancerArns>
    </member></TargetGroups></DescribeTargetGroupsResult></DescribeTargetGroupsResponse>
    """

    %{target_groups: [group]} = AWS.ElasticLoadBalancingV2.parse_describe_target_groups(xml)

    # HealthCheckPort is documented as a String; "traffic-port" is a legal value.
    assert group.health_check_port == "traffic-port"
    assert group.health_check_path == "/health"
    assert group.matcher.http_code == "200"
    assert group.load_balancer_arns == ["arn:lb/1"]
  end

  test "the default rule's priority stays the literal string \"default\"" do
    xml = """
    <DescribeRulesResponse><DescribeRulesResult><Rules>
    <member><RuleArn>arn:rule/def</RuleArn><Priority>default</Priority><IsDefault>true</IsDefault>
    <Conditions /><Actions><member><Type>forward</Type></member></Actions></member>
    </Rules></DescribeRulesResult></DescribeRulesResponse>
    """

    %{rules: [rule]} = AWS.ElasticLoadBalancingV2.parse_describe_rules(xml)

    assert rule.priority == "default"
  end

  test "a query-string condition parses key/value pairs, not bare strings" do
    xml = """
    <DescribeRulesResponse><DescribeRulesResult><Rules><member>
    <RuleArn>arn:rule/1</RuleArn><Priority>10</Priority><IsDefault>false</IsDefault>
    <Conditions><member><Field>query-string</Field><QueryStringConfig><Values>
    <member><Key>ver</Key><Value>2</Value></member>
    </Values></QueryStringConfig></member></Conditions>
    <Actions><member><Type>redirect</Type><RedirectConfig>
    <StatusCode>HTTP_301</StatusCode><Port>443</Port></RedirectConfig></member></Actions>
    </member></Rules></DescribeRulesResult></DescribeRulesResponse>
    """

    %{rules: [rule]} = AWS.ElasticLoadBalancingV2.parse_describe_rules(xml)
    [condition] = rule.conditions
    [action] = rule.actions

    assert condition.query_string_values == [%{key: "ver", value: "2"}]
    # RedirectConfig.Port is documented as a String, not an Integer.
    assert action.redirect.port == "443"
    assert action.redirect.status_code == "HTTP_301"
  end

  test "STS AssumeRole surfaces the assumed role identity, not just credentials" do
    xml = """
    <AssumeRoleResponse><AssumeRoleResult>
    <Credentials><AccessKeyId>AK</AccessKeyId><SecretAccessKey>SK</SecretAccessKey>
    <SessionToken>ST</SessionToken><Expiration>2030-01-01T00:00:00Z</Expiration></Credentials>
    <AssumedRoleUser><Arn>arn:aws:sts::1:assumed-role/r/s</Arn>
    <AssumedRoleId>AROA:s</AssumedRoleId></AssumedRoleUser>
    <PackedPolicySize>6</PackedPolicySize>
    </AssumeRoleResult></AssumeRoleResponse>
    """

    {:ok, creds} = AWS.STS.parse_assume_role_for_test(xml)

    assert creds.assumed_role_arn == "arn:aws:sts::1:assumed-role/r/s"
    assert creds.assumed_role_id == "AROA:s"
    assert creds.packed_policy_size == 6
  end

  test "an S3 notification configuration parses queue and lambda targets, not just EventBridge" do
    xml = """
    <NotificationConfiguration>
    <QueueConfiguration><Id>q1</Id><Queue>arn:aws:sqs:us-east-1:1:q</Queue>
    <Event>s3:ObjectCreated:*</Event>
    <Filter><S3Key><FilterRule><Name>prefix</Name><Value>logs/</Value></FilterRule></S3Key></Filter>
    </QueueConfiguration>
    <CloudFunctionConfiguration><Id>f1</Id>
    <CloudFunction>arn:aws:lambda:us-east-1:1:function:f</CloudFunction>
    <Event>s3:ObjectRemoved:*</Event></CloudFunctionConfiguration>
    <EventBridgeConfiguration></EventBridgeConfiguration>
    </NotificationConfiguration>
    """

    parsed = AWS.S3.XMLParser.parse_notification_configuration(xml)

    assert parsed.event_bridge_enabled
    assert [queue] = parsed.queue_configurations
    assert queue.queue == "arn:aws:sqs:us-east-1:1:q"
    assert queue.events == ["s3:ObjectCreated:*"]
    assert queue.filter_rules == [%{name: "prefix", value: "logs/"}]

    # The wire element is CloudFunctionConfiguration/CloudFunction, not the
    # model's LambdaFunctionConfiguration/LambdaFunctionArn.
    assert [fun] = parsed.cloud_function_configurations
    assert fun.cloud_function == "arn:aws:lambda:us-east-1:1:function:f"
  end

  test "DescribeInstances mirrors AWS's nesting instead of flattening it" do
    xml = """
    <DescribeInstancesResponse><reservationSet><item>
    <reservationId>r-1</reservationId><ownerId>111</ownerId>
    <instancesSet><item>
    <instanceId>i-1</instanceId><imageId>ami-1</imageId><instanceType>t3.micro</instanceType>
    <privateIpAddress>10.0.0.5</privateIpAddress><ipAddress>1.2.3.4</ipAddress>
    <dnsName>ec2-1-2-3-4.compute.amazonaws.com</dnsName>
    <subnetId>subnet-1</subnetId><vpcId>vpc-1</vpcId><launchTime>2026-01-01T00:00:00Z</launchTime>
    <instanceState><code>16</code><name>running</name></instanceState>
    <placement><availabilityZone>us-east-1a</availabilityZone><groupName>g</groupName>
    <tenancy>default</tenancy></placement>
    <cpuOptions><coreCount>2</coreCount><threadsPerCore>1</threadsPerCore></cpuOptions>
    <metadataOptions><httpTokens>required</httpTokens><httpPutResponseHopLimit>2</httpPutResponseHopLimit>
    </metadataOptions>
    <iamInstanceProfile><arn>arn:aws:iam::111:instance-profile/p</arn><id>AIPA1</id></iamInstanceProfile>
    <blockDeviceMapping><item><deviceName>/dev/xvda</deviceName>
    <ebs><volumeId>vol-1</volumeId><status>attached</status></ebs></item></blockDeviceMapping>
    <networkInterfaceSet><item><networkInterfaceId>eni-1</networkInterfaceId>
    <association><publicIp>1.2.3.4</publicIp><ipOwnerId>amazon</ipOwnerId></association>
    <attachment><attachmentId>eni-attach-1</attachmentId><deviceIndex>0</deviceIndex></attachment>
    <groupSet><item><groupId>sg-9</groupId><groupName>eni-sg</groupName></item></groupSet>
    </item></networkInterfaceSet>
    <tagSet><item><key>Name</key><value>web</value></item></tagSet>
    <groupSet><item><groupId>sg-1</groupId><groupName>web</groupName></item></groupSet>
    </item></instancesSet>
    </item></reservationSet></DescribeInstancesResponse>
    """

    parsed = AWS.EC2.parse_describe_instances_for_test(xml)

    assert [reservation] = parsed.reservation_set
    assert [instance] = reservation.instances_set

    # Sub-structures stay sub-structures.
    assert instance.instance_state == %{code: 16, name: "running"}
    assert instance.placement.group_name == "g"
    assert instance.placement.availability_zone == "us-east-1a"
    assert instance.cpu_options.core_count == 2
    assert instance.cpu_options.threads_per_core == 1
    assert instance.metadata_options.http_put_response_hop_limit == 2
    assert instance.iam_instance_profile.arn == "arn:aws:iam::111:instance-profile/p"

    # Member names are AWS's, not the library's.
    assert instance.ip_address == "1.2.3.4"
    assert instance.dns_name == "ec2-1-2-3-4.compute.amazonaws.com"
    refute Map.has_key?(instance, :public_ip_address)
    refute Map.has_key?(instance, :state)
    refute Map.has_key?(instance, :placement_group_name)

    # Nested lists keep their own sub-structures.
    assert [%{device_name: "/dev/xvda", ebs: ebs}] = instance.block_device_mapping
    assert ebs.volume_id == "vol-1"
    assert [eni] = instance.network_interface_set
    assert eni.association.public_ip == "1.2.3.4"
    assert eni.attachment.device_index == 0

    # `groupSet` resolves per level rather than being renamed differently at each.
    assert eni.group_set == [%{group_id: "sg-9", group_name: "eni-sg"}]
    assert instance.group_set == [%{group_id: "sg-1", group_name: "web"}]
    assert instance.tag_set == [%{key: "Name", value: "web"}]
  end

  test "an instance-store block device yields a nil :ebs rather than an empty-string snapshot" do
    xml = """
    <DescribeImagesResponse><imagesSet><item>
    <imageId>ami-1</imageId><name>n</name><imageState>available</imageState>
    <imageOwnerId>111</imageOwnerId><creationDate>2026-01-01T00:00:00Z</creationDate>
    <stateReason><code>c</code><message>m</message></stateReason>
    <blockDeviceMapping>
    <item><deviceName>/dev/xvda</deviceName><ebs><snapshotId>snap-1</snapshotId></ebs></item>
    <item><deviceName>/dev/sdb</deviceName><virtualName>ephemeral0</virtualName></item>
    </blockDeviceMapping>
    </item></imagesSet></DescribeImagesResponse>
    """

    assert %{images_set: [image]} = AWS.EC2.parse_describe_images_for_test(xml)
    assert image.image_state == "available"
    assert image.state_reason == %{code: "c", message: "m"}

    assert [ebs_backed, instance_store] = image.block_device_mapping
    assert ebs_backed.ebs.snapshot_id == "snap-1"
    assert instance_store.ebs == nil
  end
end
