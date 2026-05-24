defmodule AWS.STSTest do
  use ExUnit.Case

  alias AWS.STS
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} = TestCowboyServer.start(fn req -> :cowboy_req.reply(200, req) end)
    on_exit(fn -> TestCowboyServer.stop() end)

    sts_opts = [
      access_key_id: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      sts: [scheme: "http", host: "127.0.0.1", port: port]
    ]

    %{port: port, sts_opts: sts_opts}
  end

  # -- request format ----------------------------------------------------------

  describe "request format" do
    test "sends form-urlencoded body with Action and Version", %{sts_opts: sts_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        send(test_pid, {:content_type, :cowboy_req.header("content-type", req)})
        reply_xml(req, 200, caller_identity_xml())
      end)

      assert {:ok, _} = STS.get_caller_identity(sts_opts)

      assert_receive {:body, body}
      assert_receive {:content_type, "application/x-www-form-urlencoded"}

      decoded = URI.decode_query(body)
      assert decoded["Action"] === "GetCallerIdentity"
      assert decoded["Version"] === "2011-06-15"
    end

    test "does not send X-Amz-Target header (Query protocol)", %{sts_opts: sts_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:target, :cowboy_req.header("x-amz-target", req)})
        reply_xml(req, 200, caller_identity_xml())
      end)

      assert {:ok, _} = STS.get_caller_identity(sts_opts)
      assert_receive {:target, :undefined}
    end

    test "includes SigV4 authorization header scoped to sts", %{sts_opts: sts_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:auth, :cowboy_req.header("authorization", req)})
        reply_xml(req, 200, caller_identity_xml())
      end)

      assert {:ok, _} = STS.get_caller_identity(sts_opts)

      assert_receive {:auth, "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/" <> rest}
      assert rest =~ "/us-east-1/sts/aws4_request"
    end
  end

  # -- response parsing --------------------------------------------------------

  describe "response parsing" do
    test "parses GetCallerIdentityResult into snake-cased map", %{sts_opts: sts_opts} do
      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, caller_identity_xml()) end)

      assert {:ok,
              %{
                account: "123456789012",
                arn: "arn:aws:iam::123456789012:user/alice",
                user_id: "AIDA1234EXAMPLE"
              }} = STS.get_caller_identity(sts_opts)
    end
  end

  # -- error paths -------------------------------------------------------------

  describe "error paths" do
    test "4xx maps to ErrorMessage with :not_found code", %{sts_opts: sts_opts} do
      xml = """
      <ErrorResponse><Error><Code>InvalidClientTokenId</Code>\
      <Message>The security token included in the request is invalid.</Message>\
      </Error></ErrorResponse>\
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 403, xml) end)

      assert {:error, %ErrorMessage{code: :not_found}} =
               STS.get_caller_identity(sts_opts)
    end

    test "5xx maps to ErrorMessage with :service_unavailable code", %{sts_opts: sts_opts} do
      xml = "<ErrorResponse><Error><Code>ServiceFailure</Code></Error></ErrorResponse>"
      TestCowboyServer.set_handler(fn req -> reply_xml(req, 500, xml) end)

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               STS.get_caller_identity(sts_opts)
    end

    test "transport error maps to ErrorMessage with :internal_server_error code" do
      bad_opts = [
        access_key_id: "AKIA",
        secret_access_key: "secret",
        sts: [scheme: "http", host: "127.0.0.1", port: 1],
        http: [connect_timeout: 500]
      ]

      assert {:error, %ErrorMessage{code: :internal_server_error}} =
               STS.get_caller_identity(bad_opts)
    end
  end

  # -- helpers -----------------------------------------------------------------

  defp reply_xml(req, status, xml) do
    :cowboy_req.reply(status, %{"content-type" => "text/xml"}, xml, req)
  end

  defp caller_identity_xml do
    """
    <GetCallerIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">\
    <GetCallerIdentityResult>\
    <Account>123456789012</Account>\
    <Arn>arn:aws:iam::123456789012:user/alice</Arn>\
    <UserId>AIDA1234EXAMPLE</UserId>\
    </GetCallerIdentityResult>\
    <ResponseMetadata><RequestId>req-1</RequestId></ResponseMetadata>\
    </GetCallerIdentityResponse>\
    """
  end
end
