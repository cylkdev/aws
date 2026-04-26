defmodule AWS.Credentials.Providers.ECSTest do
  use ExUnit.Case

  alias AWS.Credentials.Providers.ECS
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} =
      TestCowboyServer.start(fn req ->
        :cowboy_req.reply(500, %{}, "no handler", req)
      end)

    on_exit(fn ->
      TestCowboyServer.stop()
      System.delete_env("AWS_CONTAINER_CREDENTIALS_FULL_URI")
      System.delete_env("AWS_CONTAINER_CREDENTIALS_RELATIVE_URI")
      System.delete_env("AWS_CONTAINER_AUTHORIZATION_TOKEN")
    end)

    %{port: port}
  end

  test "skip when no container env vars are set" do
    System.delete_env("AWS_CONTAINER_CREDENTIALS_FULL_URI")
    System.delete_env("AWS_CONTAINER_CREDENTIALS_RELATIVE_URI")

    assert :skip = ECS.resolve([])
  end

  test "fetches credentials from the full URI endpoint", %{port: port} do
    TestCowboyServer.set_handler(fn req ->
      body =
        :json.encode(%{
          "AccessKeyId" => "AKIA",
          "SecretAccessKey" => "SECRET",
          "Token" => "TOKEN",
          "Expiration" => "2099-01-01T00:00:00Z"
        })

      :cowboy_req.reply(200, %{"content-type" => "application/json"}, body, req)
    end)

    System.put_env("AWS_CONTAINER_CREDENTIALS_FULL_URI", "http://127.0.0.1:#{port}/creds")

    assert {:ok,
            %{
              access_key_id: "AKIA",
              secret_access_key: "SECRET",
              security_token: "TOKEN",
              source: :ecs,
              expires_at: %DateTime{}
            }} = ECS.resolve([])
  end

  test "rejects non-loopback plain-http full URIs" do
    System.put_env("AWS_CONTAINER_CREDENTIALS_FULL_URI", "http://example.com/creds")
    assert :skip = ECS.resolve([])
  end

  test "passes the authorization header when set", %{port: port} do
    parent = self()

    TestCowboyServer.set_handler(fn req ->
      auth = :cowboy_req.header("authorization", req)
      send(parent, {:auth, auth})

      body =
        :json.encode(%{
          "AccessKeyId" => "AKIA",
          "SecretAccessKey" => "SECRET"
        })

      :cowboy_req.reply(200, %{"content-type" => "application/json"}, body, req)
    end)

    System.put_env("AWS_CONTAINER_CREDENTIALS_FULL_URI", "http://127.0.0.1:#{port}/creds")
    System.put_env("AWS_CONTAINER_AUTHORIZATION_TOKEN", "TASKTOKEN")

    assert {:ok, %{source: :ecs}} = ECS.resolve([])
    assert_receive {:auth, "TASKTOKEN"}
  end
end
