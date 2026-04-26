defmodule AWS.IAMTest do
  use ExUnit.Case

  alias AWS.IAM
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} = TestCowboyServer.start(fn req -> :cowboy_req.reply(200, req) end)
    on_exit(fn -> TestCowboyServer.stop() end)

    iam_opts = [
      access_key_id: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      iam: [scheme: "http", host: "127.0.0.1", port: port]
    ]

    %{port: port, iam_opts: iam_opts}
  end

  # -- request format -----------------------------------------------------------

  describe "request format" do
    test "sends form-urlencoded body with Action and Version", %{iam_opts: iam_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, body})
        send(test_pid, {:content_type, :cowboy_req.header("content-type", req)})
        reply_xml(req, 200, create_user_xml("alice"))
      end)

      assert {:ok, _} = IAM.create_user("alice", iam_opts)

      assert_receive {:body, body}
      assert_receive {:content_type, "application/x-www-form-urlencoded"}

      decoded = URI.decode_query(body)
      assert decoded["Action"] === "CreateUser"
      assert decoded["Version"] === "2010-05-08"
      assert decoded["UserName"] === "alice"
    end

    test "does not send X-Amz-Target header (Query protocol)", %{iam_opts: iam_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:target, :cowboy_req.header("x-amz-target", req)})
        reply_xml(req, 200, create_user_xml("alice"))
      end)

      assert {:ok, _} = IAM.create_user("alice", iam_opts)
      assert_receive {:target, :undefined}
    end

    test "includes SigV4 authorization header", %{iam_opts: iam_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:auth, :cowboy_req.header("authorization", req)})
        reply_xml(req, 200, create_user_xml("alice"))
      end)

      assert {:ok, _} = IAM.create_user("alice", iam_opts)
      assert_receive {:auth, "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/" <> _}
    end
  end

  # -- response parsing --------------------------------------------------------

  describe "response parsing" do
    test "create_user parses User element", %{iam_opts: iam_opts} do
      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, create_user_xml("alice")) end)

      assert {:ok,
              %{
                user_name: "alice",
                user_id: "AIDA123",
                arn: "arn:aws:iam::123:user/alice",
                path: "/",
                create_date: "2024-01-01T00:00:00Z"
              }} = IAM.create_user("alice", iam_opts)
    end

    test "get_user parses User element", %{iam_opts: iam_opts} do
      xml = """
      <GetUserResponse><GetUserResult><User>\
      <UserName>alice</UserName><UserId>AIDA123</UserId>\
      <Arn>arn:aws:iam::123:user/alice</Arn><Path>/</Path>\
      <CreateDate>2024-01-01T00:00:00Z</CreateDate>\
      </User></GetUserResult></GetUserResponse>\
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, xml) end)

      assert {:ok, %{user_name: "alice", user_id: "AIDA123"}} =
               IAM.get_user("alice", iam_opts)
    end

    test "list_users parses member list and pagination", %{iam_opts: iam_opts} do
      xml = """
      <ListUsersResponse><ListUsersResult>\
      <Users>\
      <member><UserName>alice</UserName><UserId>AIDA1</UserId>\
      <Arn>arn:aws:iam::123:user/alice</Arn><Path>/</Path>\
      <CreateDate>2024-01-01T00:00:00Z</CreateDate></member>\
      <member><UserName>bob</UserName><UserId>AIDA2</UserId>\
      <Arn>arn:aws:iam::123:user/bob</Arn><Path>/</Path>\
      <CreateDate>2024-01-02T00:00:00Z</CreateDate></member>\
      </Users>\
      <IsTruncated>false</IsTruncated>\
      </ListUsersResult></ListUsersResponse>\
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, xml) end)

      assert {:ok,
              %{
                users: [%{user_name: "alice"}, %{user_name: "bob"}],
                is_truncated: false,
                marker: nil
              }} = IAM.list_users(iam_opts)
    end

    test "create_access_key parses AccessKey element", %{iam_opts: iam_opts} do
      xml = """
      <CreateAccessKeyResponse><CreateAccessKeyResult><AccessKey>\
      <AccessKeyId>AKIA123</AccessKeyId>\
      <SecretAccessKey>wJalr</SecretAccessKey>\
      <UserName>alice</UserName>\
      <Status>Active</Status>\
      <CreateDate>2024-01-01T00:00:00Z</CreateDate>\
      </AccessKey></CreateAccessKeyResult></CreateAccessKeyResponse>\
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, xml) end)

      assert {:ok,
              %{
                access_key_id: "AKIA123",
                secret_access_key: "wJalr",
                user_name: "alice",
                status: "Active"
              }} = IAM.create_access_key("alice", iam_opts)
    end

    test "list_roles parses Roles/member list", %{iam_opts: iam_opts} do
      xml = """
      <ListRolesResponse><ListRolesResult><Roles>\
      <member><RoleName>AdminRole</RoleName><RoleId>AROA1</RoleId>\
      <Arn>arn:aws:iam::123:role/AdminRole</Arn><Path>/</Path>\
      <CreateDate>2024-01-01T00:00:00Z</CreateDate></member>\
      </Roles></ListRolesResult></ListRolesResponse>\
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, xml) end)

      assert {:ok, %{roles: [%{role_name: "AdminRole", role_id: "AROA1"}]}} =
               IAM.list_roles(iam_opts)
    end

    test "get_account_summary parses integer entries into a map", %{iam_opts: iam_opts} do
      xml = """
      <GetAccountSummaryResponse><GetAccountSummaryResult><SummaryMap>\
      <entry><key>Users</key><value>5</value></entry>\
      <entry><key>Groups</key><value>2</value></entry>\
      <entry><key>Roles</key><value>7</value></entry>\
      </SummaryMap></GetAccountSummaryResult></GetAccountSummaryResponse>\
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, xml) end)

      assert {:ok, %{summary_map: %{"Users" => 5, "Groups" => 2, "Roles" => 7}}} =
               IAM.get_account_summary(iam_opts)
    end

    test "delete_user returns {:ok, %{}} on empty success", %{iam_opts: iam_opts} do
      xml =
        "<DeleteUserResponse><ResponseMetadata><RequestId>req-1</RequestId></ResponseMetadata></DeleteUserResponse>"

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 200, xml) end)

      assert {:ok, %{}} = IAM.delete_user("alice", iam_opts)
    end
  end

  # -- error paths --------------------------------------------------------------

  describe "error paths" do
    test "4xx maps to ErrorMessage with :not_found code", %{iam_opts: iam_opts} do
      xml = """
      <ErrorResponse><Error><Code>NoSuchEntity</Code>\
      <Message>user not found</Message></Error></ErrorResponse>\
      """

      TestCowboyServer.set_handler(fn req -> reply_xml(req, 404, xml) end)

      assert {:error, %ErrorMessage{code: :not_found}} = IAM.get_user("ghost", iam_opts)
    end

    test "5xx maps to ErrorMessage with :service_unavailable code", %{iam_opts: iam_opts} do
      xml = "<ErrorResponse><Error><Code>ServiceFailure</Code></Error></ErrorResponse>"
      TestCowboyServer.set_handler(fn req -> reply_xml(req, 500, xml) end)

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               IAM.list_users(iam_opts)
    end

    test "transport error maps to ErrorMessage with :internal_server_error code" do
      bad_opts = [
        scheme: "http",
        host: "127.0.0.1",
        port: 1,
        access_key_id: "AKIA",
        secret_access_key: "secret"
      ]

      assert {:error, %ErrorMessage{code: :internal_server_error}} =
               IAM.list_users(iam: bad_opts, http: [connect_timeout: 500])
    end
  end

  # -- helpers ------------------------------------------------------------------

  defp reply_xml(req, status, xml) do
    :cowboy_req.reply(status, %{"content-type" => "text/xml"}, xml, req)
  end

  defp create_user_xml(user_name) do
    """
    <CreateUserResponse><CreateUserResult><User>\
    <UserName>#{user_name}</UserName>\
    <UserId>AIDA123</UserId>\
    <Arn>arn:aws:iam::123:user/#{user_name}</Arn>\
    <Path>/</Path>\
    <CreateDate>2024-01-01T00:00:00Z</CreateDate>\
    </User></CreateUserResult></CreateUserResponse>\
    """
  end
end
