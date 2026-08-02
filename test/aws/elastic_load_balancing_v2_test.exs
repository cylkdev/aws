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

  describe "describe_target_health/2" do
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
                 "arn:aws:...:targetgroup/my-tg/abc",
                 opts
               )

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeTargetHealth"
      assert decoded["TargetGroupArn"] === "arn:aws:...:targetgroup/my-tg/abc"
    end

    test "raises when the target group arn is not a binary", %{opts: opts} do
      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.describe_target_health(nil, opts)
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

    test "flattens a weighted forward action into indexed member keys" do
      assert ElasticLoadBalancingV2.flatten_query(%{
               "RuleArn" => "arn:rule/1",
               "Actions" => [
                 %{
                   "Type" => "forward",
                   "ForwardConfig" => %{
                     "TargetGroups" => [
                       %{"TargetGroupArn" => "arn:tg/green", "Weight" => 100},
                       %{"TargetGroupArn" => "arn:tg/blue", "Weight" => 0}
                     ]
                   }
                 }
               ]
             }) === %{
               "RuleArn" => "arn:rule/1",
               "Actions.member.1.Type" => "forward",
               "Actions.member.1.ForwardConfig.TargetGroups.member.1.TargetGroupArn" =>
                 "arn:tg/green",
               "Actions.member.1.ForwardConfig.TargetGroups.member.1.Weight" => "100",
               "Actions.member.1.ForwardConfig.TargetGroups.member.2.TargetGroupArn" =>
                 "arn:tg/blue",
               "Actions.member.1.ForwardConfig.TargetGroups.member.2.Weight" => "0"
             }
    end
  end

  describe "describe_load_balancers/1" do
    test "encodes Names and parses the load balancers", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})

        reply_xml(req, 200, """
        <DescribeLoadBalancersResponse>
          <DescribeLoadBalancersResult><LoadBalancers><member>
            <LoadBalancerArn>arn:lb/deployd-dev</LoadBalancerArn>
            <LoadBalancerName>deployd-dev</LoadBalancerName>
            <DNSName>deployd-dev-1.us-east-1.elb.amazonaws.com</DNSName>
            <State><Code>active</Code></State>
          </member></LoadBalancers></DescribeLoadBalancersResult>
        </DescribeLoadBalancersResponse>
        """)
      end)

      assert {:ok, %{load_balancers: [lb], next_token: nil}} =
               ElasticLoadBalancingV2.describe_load_balancers(
                 Keyword.put(opts, :names, ["deployd-dev"])
               )

      assert lb.load_balancer_arn === "arn:lb/deployd-dev"
      assert lb.dns_name === "deployd-dev-1.us-east-1.elb.amazonaws.com"
      assert lb.state === "active"

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeLoadBalancers"
      assert decoded["Names.member.1"] === "deployd-dev"
    end
  end

  describe "describe_listeners/2" do
    @listeners_xml """
    <DescribeListenersResponse>
      <DescribeListenersResult><Listeners>
        <member><ListenerArn>arn:listener/80</ListenerArn><Port>80</Port><Protocol>HTTP</Protocol></member>
        <member><ListenerArn>arn:listener/443</ListenerArn><Port>443</Port><Protocol>HTTPS</Protocol></member>
      </Listeners></DescribeListenersResult>
    </DescribeListenersResponse>
    """

    test "encodes the load balancer arn and parses ports as integers", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, @listeners_xml)
      end)

      assert {:ok, %{listeners: listeners}} =
               ElasticLoadBalancingV2.describe_listeners("arn:lb/deployd-dev", opts)

      assert Enum.find(listeners, &(&1.port === 80)).listener_arn === "arn:listener/80"

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeListeners"
      assert decoded["LoadBalancerArn"] === "arn:lb/deployd-dev"
      refute Map.has_key?(decoded, "ListenerArns.member.1")
    end

    test "raises when the load balancer arn is not a binary", %{opts: opts} do
      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.describe_listeners(nil, opts)
      end
    end
  end

  describe "describe_listeners_by_arns/2" do
    test "encodes ListenerArns.member.N rather than LoadBalancerArn", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, @listeners_xml)
      end)

      assert {:ok, %{listeners: [_ | _]}} =
               ElasticLoadBalancingV2.describe_listeners_by_arns(
                 ["arn:listener/80", "arn:listener/443"],
                 opts
               )

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeListeners"
      assert decoded["ListenerArns.member.1"] === "arn:listener/80"
      assert decoded["ListenerArns.member.2"] === "arn:listener/443"
      refute Map.has_key?(decoded, "LoadBalancerArn")
    end

    test "raises on an empty list", %{opts: opts} do
      # Built at runtime so the type checker does not reject the literal [].
      empty = List.delete(["arn:listener/80"], "arn:listener/80")

      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.describe_listeners_by_arns(empty, opts)
      end
    end
  end

  describe "describe_rules/2" do
    @rules_xml """
    <DescribeRulesResponse>
      <DescribeRulesResult><Rules><member>
        <RuleArn>arn:rule/1</RuleArn>
        <Priority>1</Priority>
        <IsDefault>false</IsDefault>
        <Conditions><member>
          <Field>host-header</Field>
          <Values><member>web.dev.deployd.internal</member></Values>
          <HostHeaderConfig><Values><member>web.dev.deployd.internal</member></Values></HostHeaderConfig>
        </member></Conditions>
        <Actions><member>
          <Type>forward</Type>
          <ForwardConfig><TargetGroups>
            <member><TargetGroupArn>arn:tg/deployd-web-dev-green</TargetGroupArn><Weight>100</Weight></member>
            <member><TargetGroupArn>arn:tg/deployd-web-dev-blue</TargetGroupArn><Weight>0</Weight></member>
          </TargetGroups></ForwardConfig>
        </member></Actions>
      </member></Rules></DescribeRulesResult>
    </DescribeRulesResponse>
    """

    test "preserves host-header conditions and weighted target groups", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, @rules_xml)
      end)

      assert {:ok, %{rules: [rule], next_token: nil}} =
               ElasticLoadBalancingV2.describe_rules("arn:listener/80", opts)

      assert rule.rule_arn === "arn:rule/1"
      assert rule.is_default === false
      assert [%{host_header_values: ["web.dev.deployd.internal"]}] = rule.conditions

      # The weights are what a blue/green deploy reads to learn which
      # color is currently live.
      assert [%{type: "forward", target_groups: target_groups}] = rule.actions

      assert Enum.max_by(target_groups, & &1.weight).target_group_arn ===
               "arn:tg/deployd-web-dev-green"

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeRules"
      assert decoded["ListenerArn"] === "arn:listener/80"
      refute Map.has_key?(decoded, "RuleArns.member.1")
    end

    test "raises when the listener arn is not a binary", %{opts: opts} do
      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.describe_rules(nil, opts)
      end
    end
  end

  describe "describe_rules_by_arns/2" do
    test "encodes RuleArns.member.N rather than ListenerArn", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        reply_xml(req, 200, @rules_xml)
      end)

      assert {:ok, %{rules: [_ | _]}} =
               ElasticLoadBalancingV2.describe_rules_by_arns(
                 ["arn:rule/1", "arn:rule/2"],
                 opts
               )

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "DescribeRules"
      assert decoded["RuleArns.member.1"] === "arn:rule/1"
      assert decoded["RuleArns.member.2"] === "arn:rule/2"
      refute Map.has_key?(decoded, "ListenerArn")
    end

    test "raises on an empty list", %{opts: opts} do
      # Built at runtime so the type checker does not reject the literal [].
      empty = List.delete(["arn:rule/1"], "arn:rule/1")

      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.describe_rules_by_arns(empty, opts)
      end
    end
  end

  describe "modify_rule/3" do
    test "encodes the nested weighted action and parses the returned rule", %{opts: opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})

        reply_xml(req, 200, """
        <ModifyRuleResponse>
          <ModifyRuleResult><Rules><member>
            <RuleArn>arn:rule/1</RuleArn><Priority>1</Priority><IsDefault>false</IsDefault>
            <Actions><member>
              <Type>forward</Type>
              <ForwardConfig><TargetGroups>
                <member><TargetGroupArn>arn:tg/green</TargetGroupArn><Weight>100</Weight></member>
              </TargetGroups></ForwardConfig>
            </member></Actions>
          </member></Rules></ModifyRuleResult>
        </ModifyRuleResponse>
        """)
      end)

      assert {:ok, %{rules: [rule]}} =
               ElasticLoadBalancingV2.modify_rule(
                 "arn:rule/1",
                 [
                   %{
                     "Type" => "forward",
                     "ForwardConfig" => %{
                       "TargetGroups" => [
                         %{"TargetGroupArn" => "arn:tg/green", "Weight" => 100},
                         %{"TargetGroupArn" => "arn:tg/blue", "Weight" => 0}
                       ]
                     }
                   }
                 ],
                 opts
               )

      assert rule.rule_arn === "arn:rule/1"

      assert_receive {:body, body}
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "ModifyRule"
      assert decoded["RuleArn"] === "arn:rule/1"
      assert decoded["Actions.member.1.Type"] === "forward"

      assert decoded["Actions.member.1.ForwardConfig.TargetGroups.member.1.TargetGroupArn"] ===
               "arn:tg/green"

      assert decoded["Actions.member.1.ForwardConfig.TargetGroups.member.1.Weight"] === "100"

      assert decoded["Actions.member.1.ForwardConfig.TargetGroups.member.2.TargetGroupArn"] ===
               "arn:tg/blue"

      assert decoded["Actions.member.1.ForwardConfig.TargetGroups.member.2.Weight"] === "0"
    end

    test "raises when the rule arn is not a binary", %{opts: opts} do
      assert_raise FunctionClauseError, fn ->
        ElasticLoadBalancingV2.modify_rule(nil, [], opts)
      end
    end
  end
end
