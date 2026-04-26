defmodule AWS.IdentityCenterTest do
  use ExUnit.Case

  alias AWS.IdentityCenter
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} = TestCowboyServer.start(fn req -> :cowboy_req.reply(200, req) end)
    on_exit(fn -> TestCowboyServer.stop() end)

    ic_opts = [
      access_key_id: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      identity_center: [scheme: "http", host: "127.0.0.1", port: port]
    ]

    %{port: port, ic_opts: ic_opts}
  end

  # -- target header + signing --------------------------------------------------

  describe "target header" do
    test "list_instances sends SWBExternalService.ListInstances", %{ic_opts: ic_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:target, :cowboy_req.header("x-amz-target", req)})
        reply_json(req, 200, %{"Instances" => []})
      end)

      assert {:ok, _} = IdentityCenter.list_instances(ic_opts)
      assert_receive {:target, "SWBExternalService.ListInstances"}
    end

    test "list_identity_store_users sends AWSIdentityStore.ListUsers", %{ic_opts: ic_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:target, :cowboy_req.header("x-amz-target", req)})
        reply_json(req, 200, %{"Users" => []})
      end)

      assert {:ok, _} =
               IdentityCenter.list_identity_store_users("d-123", ic_opts)

      assert_receive {:target, "AWSIdentityStore.ListUsers"}
    end

    test "includes SigV4 authorization header", %{ic_opts: ic_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:auth, :cowboy_req.header("authorization", req)})
        reply_json(req, 200, %{"Instances" => []})
      end)

      assert {:ok, _} = IdentityCenter.list_instances(ic_opts)
      assert_receive {:auth, "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/" <> _}
    end
  end

  # -- request body -------------------------------------------------------------

  describe "request body encoding" do
    test "create_permission_set encodes PascalCase keys", %{ic_opts: ic_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, :json.decode(body)})
        reply_json(req, 200, %{"PermissionSet" => %{"Name" => "admin"}})
      end)

      assert {:ok, _} =
               IdentityCenter.create_permission_set(
                 "arn:ins",
                 "admin",
                 ic_opts ++ [description: "admins", session_duration: "PT8H"]
               )

      assert_receive {:body, body}
      assert body["InstanceArn"] === "arn:ins"
      assert body["Name"] === "admin"
      assert body["Description"] === "admins"
      assert body["SessionDuration"] === "PT8H"
    end

    test "create_group_membership encodes nested MemberId.UserId", %{ic_opts: ic_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, :json.decode(body)})
        reply_json(req, 200, %{"MembershipId" => "m-1", "IdentityStoreId" => "d-123"})
      end)

      assert {:ok, _} =
               IdentityCenter.create_group_membership("d-123", "g-1", "u-1", ic_opts)

      assert_receive {:body, body}
      assert body["IdentityStoreId"] === "d-123"
      assert body["GroupId"] === "g-1"
      assert body["MemberId"] === %{"UserId" => "u-1"}
    end

    test "list_instances sends empty body {}", %{ic_opts: ic_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:raw_body, body})
        reply_json(req, 200, %{"Instances" => []})
      end)

      assert {:ok, _} = IdentityCenter.list_instances(ic_opts)
      assert_receive {:raw_body, "{}"}
    end
  end

  # -- response deserialization -------------------------------------------------

  describe "response deserialization" do
    test "list_instances decodes snake_case fields", %{ic_opts: ic_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 200, %{
          "Instances" => [
            %{"InstanceArn" => "arn:ins-1", "IdentityStoreId" => "d-123"}
          ]
        })
      end)

      assert {:ok,
              %{
                instances: [%{instance_arn: "arn:ins-1", identity_store_id: "d-123"}]
              }} = IdentityCenter.list_instances(ic_opts)
    end
  end

  # -- error paths --------------------------------------------------------------

  describe "error paths" do
    test "4xx maps to ErrorMessage with :not_found code", %{ic_opts: ic_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 400, %{
          "__type" => "ResourceNotFoundException",
          "message" => "not found"
        })
      end)

      assert {:error, %ErrorMessage{code: :not_found}} =
               IdentityCenter.delete_permission_set("arn:ins", "ps-missing", ic_opts)
    end

    test "5xx maps to ErrorMessage with :service_unavailable code", %{ic_opts: ic_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 500, %{"__type" => "InternalFailure"})
      end)

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               IdentityCenter.list_instances(ic_opts)
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
               IdentityCenter.list_instances(
                 identity_center: bad_opts,
                 http: [connect_timeout: 500]
               )
    end
  end

  # -- helpers ------------------------------------------------------------------

  defp reply_json(req, status, map) do
    :cowboy_req.reply(
      status,
      %{"content-type" => "application/x-amz-json-1.1"},
      map |> :json.encode() |> IO.iodata_to_binary(),
      req
    )
  end
end
