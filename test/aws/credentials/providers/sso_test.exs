defmodule AWS.Credentials.Providers.SSOTest do
  use ExUnit.Case

  alias AWS.Credentials.Providers.SSO, as: Provider
  alias AWS.CredentialsFixtures
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} =
      TestCowboyServer.start(fn req ->
        :cowboy_req.reply(500, %{}, "default handler", req)
      end)

    on_exit(fn -> TestCowboyServer.stop() end)
    %{port: port, base: "http://127.0.0.1:#{port}"}
  end

  @tag :tmp_dir
  test "skips when the profile is not configured for SSO", %{tmp_dir: tmp} do
    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        region = us-east-1
        """
      )

    assert :skip = Provider.resolve(profile: "dev", home_dir: home)
  end

  @tag :tmp_dir
  test "returns sso credentials using a modern sso_session profile", ctx do
    %{tmp_dir: tmp, base: base} = ctx

    TestCowboyServer.set_handler(fn req ->
      "/federation/credentials" = :cowboy_req.path(req)
      "bearer-token" = :cowboy_req.header("x-amz-sso_bearer_token", req)
      qs = :cowboy_req.parse_qs(req)
      assert {"account_id", "111122223333"} in qs
      assert {"role_name", "Admin"} in qs

      body =
        :json.encode(%{
          "roleCredentials" => %{
            "accessKeyId" => "AKIA",
            "secretAccessKey" => "SECRET",
            "sessionToken" => "TOKEN",
            "expiration" => 4_102_444_800_000
          }
        })

      :cowboy_req.reply(200, %{"content-type" => "application/json"}, body, req)
    end)

    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        sso_session = main
        sso_account_id = 111122223333
        sso_role_name = Admin

        [sso-session main]
        sso_region = us-east-1
        sso_start_url = https://example.awsapps.com/start
        """
      )

    CredentialsFixtures.write_sso_cache(home, "main", %{
      "accessToken" => "bearer-token",
      "expiresAt" => "2099-01-01T00:00:00Z"
    })

    assert {:ok,
            %{
              access_key_id: "AKIA",
              secret_access_key: "SECRET",
              security_token: "TOKEN",
              source: :sso,
              expires_at: %DateTime{}
            }} =
             Provider.resolve(
               profile: "dev",
               home_dir: home,
               endpoints: [portal: base]
             )
  end

  @tag :tmp_dir
  test "returns sso credentials using a legacy sso_start_url profile", ctx do
    %{tmp_dir: tmp, base: base} = ctx

    TestCowboyServer.set_handler(fn req ->
      body =
        :json.encode(%{
          "roleCredentials" => %{
            "accessKeyId" => "AKIA",
            "secretAccessKey" => "SECRET",
            "sessionToken" => "TOKEN",
            "expiration" => 4_102_444_800_000
          }
        })

      :cowboy_req.reply(200, %{"content-type" => "application/json"}, body, req)
    end)

    start_url = "https://legacy.awsapps.com/start"

    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        sso_start_url = #{start_url}
        sso_region = us-east-1
        sso_account_id = 111122223333
        sso_role_name = Admin
        """
      )

    CredentialsFixtures.write_sso_cache(home, start_url, %{
      "accessToken" => "bearer-token",
      "expiresAt" => "2099-01-01T00:00:00Z"
    })

    assert {:ok, %{source: :sso, access_key_id: "AKIA"}} =
             Provider.resolve(
               profile: "dev",
               home_dir: home,
               endpoints: [portal: base]
             )
  end

  @tag :tmp_dir
  test "returns {:error, :sso_token_expired} when cache file is missing", %{tmp_dir: tmp} do
    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        sso_session = main
        sso_account_id = 111122223333
        sso_role_name = Admin

        [sso-session main]
        sso_region = us-east-1
        sso_start_url = https://example.awsapps.com/start
        """
      )

    assert {:error, :sso_token_expired} = Provider.resolve(profile: "dev", home_dir: home)
  end

  @tag :tmp_dir
  test "returns {:error, :sso_token_expired} when token is stale and no refresh material", %{
    tmp_dir: tmp
  } do
    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        sso_session = main
        sso_account_id = 111122223333
        sso_role_name = Admin

        [sso-session main]
        sso_region = us-east-1
        sso_start_url = https://example.awsapps.com/start
        """
      )

    CredentialsFixtures.write_sso_cache(home, "main", %{
      "accessToken" => "expired",
      "expiresAt" => "2000-01-01T00:00:00Z"
    })

    assert {:error, :sso_token_expired} = Provider.resolve(profile: "dev", home_dir: home)
  end

  @tag :tmp_dir
  test "refreshes the access token via OIDC when near expiry and material present", ctx do
    %{tmp_dir: tmp, base: base} = ctx

    TestCowboyServer.set_handler(fn req ->
      case :cowboy_req.path(req) do
        "/token" ->
          {:ok, body, req} = :cowboy_req.read_body(req)
          decoded = :json.decode(body)
          assert decoded["grantType"] === "refresh_token"
          assert decoded["refreshToken"] === "RT1"

          resp =
            :json.encode(%{
              "accessToken" => "NEW-ACCESS",
              "refreshToken" => "RT2",
              "expiresIn" => 28_800,
              "tokenType" => "Bearer"
            })

          :cowboy_req.reply(200, %{"content-type" => "application/json"}, resp, req)

        "/federation/credentials" ->
          "NEW-ACCESS" = :cowboy_req.header("x-amz-sso_bearer_token", req)

          resp =
            :json.encode(%{
              "roleCredentials" => %{
                "accessKeyId" => "AKIA",
                "secretAccessKey" => "SECRET",
                "sessionToken" => "TOKEN",
                "expiration" => 4_102_444_800_000
              }
            })

          :cowboy_req.reply(200, %{"content-type" => "application/json"}, resp, req)
      end
    end)

    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        sso_session = main
        sso_account_id = 111122223333
        sso_role_name = Admin

        [sso-session main]
        sso_region = us-east-1
        sso_start_url = https://example.awsapps.com/start
        """
      )

    soon = DateTime.utc_now() |> DateTime.add(60, :second) |> DateTime.to_iso8601()
    long_future = DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.to_iso8601()

    CredentialsFixtures.write_sso_cache(home, "main", %{
      "accessToken" => "STALE",
      "expiresAt" => soon,
      "refreshToken" => "RT1",
      "clientId" => "cid",
      "clientSecret" => "csec",
      "registrationExpiresAt" => long_future
    })

    assert {:ok, %{source: :sso, access_key_id: "AKIA"}} =
             Provider.resolve(
               profile: "dev",
               home_dir: home,
               endpoints: [portal: base, oidc: base]
             )

    hash = :sha |> :crypto.hash("main") |> Base.encode16(case: :lower)
    path = Path.join(home, ".aws/sso/cache/#{hash}.json")
    updated = path |> File.read!() |> :json.decode()
    assert updated["accessToken"] === "NEW-ACCESS"
    assert updated["refreshToken"] === "RT2"
  end

  @tag :tmp_dir
  test "surfaces :sso_token_expired when OIDC refresh returns invalid_grant", ctx do
    %{tmp_dir: tmp, base: base} = ctx

    TestCowboyServer.set_handler(fn req ->
      "/token" = :cowboy_req.path(req)

      body = :json.encode(%{"error" => "invalid_grant", "error_description" => "expired"})
      :cowboy_req.reply(400, %{"content-type" => "application/json"}, body, req)
    end)

    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        sso_session = main
        sso_account_id = 111122223333
        sso_role_name = Admin

        [sso-session main]
        sso_region = us-east-1
        sso_start_url = https://example.awsapps.com/start
        """
      )

    soon = DateTime.utc_now() |> DateTime.add(60, :second) |> DateTime.to_iso8601()
    long_future = DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.to_iso8601()

    CredentialsFixtures.write_sso_cache(home, "main", %{
      "accessToken" => "STALE",
      "expiresAt" => soon,
      "refreshToken" => "revoked",
      "clientId" => "cid",
      "clientSecret" => "csec",
      "registrationExpiresAt" => long_future
    })

    assert {:error, :sso_token_expired} =
             Provider.resolve(
               profile: "dev",
               home_dir: home,
               endpoints: [portal: base, oidc: base]
             )
  end
end
