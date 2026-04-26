defmodule AWS.OrganizationsTest do
  use ExUnit.Case

  alias AWS.Organizations
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} = TestCowboyServer.start(fn req -> :cowboy_req.reply(200, req) end)
    on_exit(fn -> TestCowboyServer.stop() end)

    org_opts = [
      access_key_id: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      organizations: [scheme: "http", host: "127.0.0.1", port: port]
    ]

    %{port: port, org_opts: org_opts}
  end

  # -- target header + signing --------------------------------------------------

  describe "target header" do
    test "list_accounts sends AWSOrganizationsV20161128.ListAccounts", %{org_opts: org_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:target, :cowboy_req.header("x-amz-target", req)})
        reply_json(req, 200, %{"Accounts" => []})
      end)

      assert {:ok, _} = Organizations.list_accounts(org_opts)
      assert_receive {:target, "AWSOrganizationsV20161128.ListAccounts"}
    end

    test "create_account sends AWSOrganizationsV20161128.CreateAccount", %{org_opts: org_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:target, :cowboy_req.header("x-amz-target", req)})

        reply_json(req, 200, %{
          "CreateAccountStatus" => %{"Id" => "car-1", "State" => "IN_PROGRESS"}
        })
      end)

      assert {:ok, _} =
               Organizations.create_account("tools", "tools@example.com", org_opts)

      assert_receive {:target, "AWSOrganizationsV20161128.CreateAccount"}
    end

    test "includes SigV4 authorization header", %{org_opts: org_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        send(test_pid, {:auth, :cowboy_req.header("authorization", req)})
        reply_json(req, 200, %{"Accounts" => []})
      end)

      assert {:ok, _} = Organizations.list_accounts(org_opts)
      assert_receive {:auth, "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/" <> _}
    end
  end

  # -- request body -------------------------------------------------------------

  describe "request body encoding" do
    test "create_account encodes PascalCase keys", %{org_opts: org_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, :json.decode(body)})
        reply_json(req, 200, %{"CreateAccountStatus" => %{"Id" => "car-1"}})
      end)

      assert {:ok, _} =
               Organizations.create_account(
                 "tools",
                 "tools@example.com",
                 org_opts ++ [iam_user_access_to_billing: "DENY"]
               )

      assert_receive {:body, body}
      assert body["AccountName"] === "tools"
      assert body["Email"] === "tools@example.com"
      assert body["IamUserAccessToBilling"] === "DENY"
    end

    test "create_organizational_unit encodes ParentId and Name", %{org_opts: org_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, :json.decode(body)})
        reply_json(req, 200, %{"OrganizationalUnit" => %{"Id" => "ou-1", "Name" => "Workloads"}})
      end)

      assert {:ok, _} =
               Organizations.create_organizational_unit("r-abcd", "Workloads", org_opts)

      assert_receive {:body, body}
      assert body["ParentId"] === "r-abcd"
      assert body["Name"] === "Workloads"
    end

    test "delete_organizational_unit encodes OrganizationalUnitId", %{org_opts: org_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:body, :json.decode(body)})
        reply_json(req, 200, %{})
      end)

      assert {:ok, _} =
               Organizations.delete_organizational_unit("ou-1", org_opts)

      assert_receive {:body, body}
      assert body["OrganizationalUnitId"] === "ou-1"
    end

    test "list_roots sends empty body {}", %{org_opts: org_opts} do
      test_pid = self()

      TestCowboyServer.set_handler(fn req ->
        {:ok, body, req} = :cowboy_req.read_body(req)
        send(test_pid, {:raw_body, body})
        reply_json(req, 200, %{"Roots" => []})
      end)

      assert {:ok, _} = Organizations.list_roots(org_opts)
      assert_receive {:raw_body, "{}"}
    end
  end

  # -- response deserialization -------------------------------------------------

  describe "response deserialization" do
    test "list_accounts decodes snake_case fields", %{org_opts: org_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 200, %{
          "Accounts" => [
            %{"Id" => "111122223333", "Name" => "tools", "Email" => "tools@example.com"}
          ]
        })
      end)

      assert {:ok,
              %{
                accounts: [%{id: "111122223333", name: "tools", email: "tools@example.com"}]
              }} = Organizations.list_accounts(org_opts)
    end

    test "list_organizational_units_for_parent returns deserialized OUs", %{org_opts: org_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 200, %{
          "OrganizationalUnits" => [%{"Id" => "ou-1", "Name" => "Workloads"}]
        })
      end)

      assert {:ok, %{organizational_units: [%{id: "ou-1", name: "Workloads"}]}} =
               Organizations.list_organizational_units_for_parent(
                 "r-abcd",
                 org_opts
               )
    end

    test "describe_create_account_status decodes nested status", %{org_opts: org_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 200, %{
          "CreateAccountStatus" => %{
            "Id" => "car-1",
            "State" => "SUCCEEDED",
            "AccountId" => "111122223333"
          }
        })
      end)

      assert {:ok,
              %{
                create_account_status: %{
                  id: "car-1",
                  state: "SUCCEEDED",
                  account_id: "111122223333"
                }
              }} =
               Organizations.describe_create_account_status("car-1", org_opts)
    end
  end

  # -- error paths --------------------------------------------------------------

  describe "error paths" do
    test "4xx maps to ErrorMessage with :not_found code", %{org_opts: org_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 400, %{
          "__type" => "AWSOrganizationsNotInUseException",
          "Message" => "no organization"
        })
      end)

      assert {:error, %ErrorMessage{code: :not_found}} =
               Organizations.describe_organization(org_opts)
    end

    test "5xx maps to ErrorMessage with :service_unavailable code", %{org_opts: org_opts} do
      TestCowboyServer.set_handler(fn req ->
        reply_json(req, 500, %{"__type" => "ServiceException"})
      end)

      assert {:error, %ErrorMessage{code: :service_unavailable}} =
               Organizations.list_accounts(org_opts)
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
               Organizations.list_accounts(
                 organizations: bad_opts,
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
