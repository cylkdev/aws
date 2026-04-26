defmodule AWS.Credentials.Providers.IMDSTest do
  use ExUnit.Case

  alias AWS.Credentials.Providers.IMDS
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} =
      TestCowboyServer.start(fn req ->
        :cowboy_req.reply(500, %{}, "no handler", req)
      end)

    on_exit(fn ->
      TestCowboyServer.stop()
      System.delete_env("AWS_EC2_METADATA_DISABLED")
    end)

    %{port: port, endpoint: "http://127.0.0.1:#{port}"}
  end

  test "skip when AWS_EC2_METADATA_DISABLED=true" do
    System.put_env("AWS_EC2_METADATA_DISABLED", "true")
    assert :skip = IMDS.resolve([])
  end

  test "walks the IMDSv2 handshake and returns credentials", %{endpoint: endpoint} do
    TestCowboyServer.set_handler(fn req ->
      case {:cowboy_req.method(req), :cowboy_req.path(req)} do
        {"PUT", "/latest/api/token"} ->
          :cowboy_req.reply(200, %{"content-type" => "text/plain"}, "TOKEN-XYZ", req)

        {"GET", "/latest/meta-data/iam/security-credentials/"} ->
          "TOKEN-XYZ" = :cowboy_req.header("x-aws-ec2-metadata-token", req)
          :cowboy_req.reply(200, %{"content-type" => "text/plain"}, "my-role\n", req)

        {"GET", "/latest/meta-data/iam/security-credentials/my-role"} ->
          "TOKEN-XYZ" = :cowboy_req.header("x-aws-ec2-metadata-token", req)

          body =
            :json.encode(%{
              "AccessKeyId" => "AKIA",
              "SecretAccessKey" => "SECRET",
              "Token" => "SESSION",
              "Expiration" => "2099-01-01T00:00:00Z"
            })

          :cowboy_req.reply(200, %{"content-type" => "application/json"}, body, req)
      end
    end)

    assert {:ok,
            %{
              access_key_id: "AKIA",
              secret_access_key: "SECRET",
              security_token: "SESSION",
              source: :imds,
              expires_at: %DateTime{}
            }} = IMDS.resolve(endpoint: endpoint)
  end

  test "returns an error when the token endpoint is unreachable" do
    assert {:error, _} = IMDS.resolve(endpoint: "http://127.0.0.1:1")
  end
end
