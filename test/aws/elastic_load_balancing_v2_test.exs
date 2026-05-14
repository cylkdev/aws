defmodule AWS.ElasticLoadBalancingV2Test do
  use ExUnit.Case

  alias AWS.ElasticLoadBalancingV2
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} = TestCowboyServer.start(fn req -> :cowboy_req.reply(200, req) end)
    on_exit(fn -> TestCowboyServer.stop() end)

    opts = [
      access_key_id: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      region: "us-east-1",
      elastic_load_balancing_v2: [scheme: "http", host: "127.0.0.1", port: port]
    ]

    %{port: port, opts: opts}
  end

  defp reply_xml(req, status, body) do
    :cowboy_req.reply(status, %{"content-type" => "text/xml"}, body, req)
  end

  defp empty_describe_target_groups_xml do
    """
    <DescribeTargetGroupsResponse xmlns="http://elasticloadbalancing.amazonaws.com/doc/2015-12-01/">
      <DescribeTargetGroupsResult><TargetGroups/></DescribeTargetGroupsResult>
      <ResponseMetadata><RequestId>req-1</RequestId></ResponseMetadata>
    </DescribeTargetGroupsResponse>
    """
  end

  describe "request format" do
    test "encodes form-urlencoded body with Action, Version, and Names.member.N", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        send(test_pid, {:content_type, :cowboy_req.header("content-type", req)})
        reply_xml(req, 200, empty_describe_target_groups_xml())
      end)

      assert {:ok, _} =
               ElasticLoadBalancingV2.describe_target_groups(
                 Keyword.put(opts, :names, ["tg-a", "tg-b"])
               )

      assert_receive {:content_type, "application/x-www-form-urlencoded"}
      assert_receive {:body, body}

      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeTargetGroups"
      assert decoded["Version"] === "2015-12-01"
      assert decoded["Names.member.1"] === "tg-a"
      assert decoded["Names.member.2"] === "tg-b"
    end

    test "request is signed with service=elasticloadbalancing", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:auth, :cowboy_req.header("authorization", req)})
        reply_xml(req, 200, empty_describe_target_groups_xml())
      end)

      assert {:ok, _} = ElasticLoadBalancingV2.describe_target_groups(opts)
      assert_receive {:auth, auth}
      assert is_binary(auth)
      assert auth =~ "/elasticloadbalancing/aws4_request"
    end

    test "encodes :next_token as Marker on the wire", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, empty_describe_target_groups_xml())
      end)

      assert {:ok, _} =
               ElasticLoadBalancingV2.describe_target_groups(
                 Keyword.put(opts, :next_token, "tok-1")
               )

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Marker"] === "tok-1"
    end
  end

  describe "describe_target_groups/1 response parsing" do
    test "parses TargetGroups members and NextMarker as next_token", %{opts: opts} do
      xml = ~s"""
      <DescribeTargetGroupsResponse xmlns="http://elasticloadbalancing.amazonaws.com/doc/2015-12-01/">
        <DescribeTargetGroupsResult>
          <TargetGroups>
            <member>
              <TargetGroupArn>arn:aws:elasticloadbalancing:us-east-1:123:targetgroup/my-tg/abc</TargetGroupArn>
              <TargetGroupName>my-tg</TargetGroupName>
              <Port>80</Port>
              <Protocol>HTTP</Protocol>
            </member>
            <member>
              <TargetGroupArn>arn:aws:elasticloadbalancing:us-east-1:123:targetgroup/other-tg/def</TargetGroupArn>
              <TargetGroupName>other-tg</TargetGroupName>
            </member>
          </TargetGroups>
          <NextMarker>page-2</NextMarker>
        </DescribeTargetGroupsResult>
      </DescribeTargetGroupsResponse>
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, xml) end)

      assert {:ok,
              %{
                target_groups: [
                  %{
                    target_group_arn:
                      "arn:aws:elasticloadbalancing:us-east-1:123:targetgroup/my-tg/abc",
                    target_group_name: "my-tg"
                  },
                  %{
                    target_group_arn:
                      "arn:aws:elasticloadbalancing:us-east-1:123:targetgroup/other-tg/def",
                    target_group_name: "other-tg"
                  }
                ],
                next_token: "page-2"
              }} = ElasticLoadBalancingV2.describe_target_groups(opts)
    end

    test "empty TargetGroups produces empty list and nil next_token", %{opts: opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_xml(req, 200, empty_describe_target_groups_xml())
      end)

      assert {:ok, %{target_groups: [], next_token: nil}} =
               ElasticLoadBalancingV2.describe_target_groups(opts)
    end
  end

  describe "describe_target_health/1" do
    test "encodes TargetGroupArn and parses TargetHealthDescriptions", %{opts: opts} do
      test_pid = self()

      xml = ~s"""
      <DescribeTargetHealthResponse xmlns="http://elasticloadbalancing.amazonaws.com/doc/2015-12-01/">
        <DescribeTargetHealthResult>
          <TargetHealthDescriptions>
            <member>
              <Target>
                <Id>i-0abc</Id>
                <Port>4000</Port>
              </Target>
              <TargetHealth>
                <State>healthy</State>
              </TargetHealth>
            </member>
            <member>
              <Target>
                <Id>i-0def</Id>
                <Port>4000</Port>
              </Target>
              <TargetHealth>
                <State>unhealthy</State>
                <Reason>Target.FailedHealthChecks</Reason>
              </TargetHealth>
            </member>
          </TargetHealthDescriptions>
        </DescribeTargetHealthResult>
      </DescribeTargetHealthResponse>
      """

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, xml)
      end)

      assert {:ok,
              %{
                target_health_descriptions: [
                  %{target_id: "i-0abc", port: 4000, state: "healthy"},
                  %{target_id: "i-0def", port: 4000, state: "unhealthy"}
                ]
              }} =
               ElasticLoadBalancingV2.describe_target_health(
                 Keyword.put(opts, :target_group_arn, "arn:aws:...:targetgroup/my-tg/abc")
               )

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeTargetHealth"
      assert decoded["TargetGroupArn"] === "arn:aws:...:targetgroup/my-tg/abc"
    end

    test "raises when :target_group_arn is missing", %{opts: opts} do
      assert_raise ArgumentError, ~r/:target_group_arn/, fn ->
        ElasticLoadBalancingV2.describe_target_health(opts)
      end
    end
  end

  describe "flatten_query/1" do
    test "flattens scalar, list, and nested map values" do
      assert ElasticLoadBalancingV2.flatten_query(%{
               "Names" => ["a", "b"],
               "Marker" => "tok",
               "Empty" => nil
             }) === %{
               "Names.member.1" => "a",
               "Names.member.2" => "b",
               "Marker" => "tok"
             }
    end
  end
end
