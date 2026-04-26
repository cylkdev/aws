defmodule AWS.Credentials.Providers.AssumeRoleTest do
  use ExUnit.Case

  alias AWS.Credentials.Providers.AssumeRole
  alias AWS.CredentialsFixtures
  alias AWS.TestCowboyServer

  setup do
    {:ok, port} =
      TestCowboyServer.start(fn req ->
        :cowboy_req.reply(500, %{}, "no handler", req)
      end)

    on_exit(fn -> TestCowboyServer.stop() end)
    %{port: port, base: "http://127.0.0.1:#{port}/"}
  end

  @tag :tmp_dir
  test "skip when profile has no role_arn", %{tmp_dir: tmp} do
    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        region = us-east-1
        """
      )

    assert :skip = AssumeRole.resolve(profile: "dev", home_dir: home)
  end

  @tag :tmp_dir
  test "errors when role_arn exists but source_profile is missing", %{tmp_dir: tmp} do
    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        role_arn = arn:aws:iam::111:role/x
        """
      )

    assert {:error, :assume_role_missing_source_profile} =
             AssumeRole.resolve(profile: "dev", home_dir: home)
  end

  @tag :tmp_dir
  test "assumes the role using the source profile and returns sts creds", ctx do
    %{tmp_dir: tmp, base: base} = ctx

    TestCowboyServer.set_handler(fn req ->
      {:ok, body, req} = :cowboy_req.read_body(req)
      decoded = URI.decode_query(body)
      assert decoded["Action"] === "AssumeRole"
      assert decoded["RoleArn"] === "arn:aws:iam::111:role/x"
      assert decoded["RoleSessionName"] !== nil

      xml = """
      <AssumeRoleResponse>
        <AssumeRoleResult>
          <Credentials>
            <AccessKeyId>ASIA</AccessKeyId>
            <SecretAccessKey>sts-secret</SecretAccessKey>
            <SessionToken>sts-token</SessionToken>
            <Expiration>2099-01-01T00:00:00Z</Expiration>
          </Credentials>
        </AssumeRoleResult>
      </AssumeRoleResponse>
      """

      :cowboy_req.reply(200, %{"content-type" => "text/xml"}, xml, req)
    end)

    home =
      CredentialsFixtures.build_home(tmp,
        credentials: """
        [base]
        aws_access_key_id = AKIABASE
        aws_secret_access_key = base-secret
        """,
        config: """
        [profile dev]
        role_arn = arn:aws:iam::111:role/x
        source_profile = base
        region = us-east-1
        """
      )

    assert {:ok,
            %{
              access_key_id: "ASIA",
              secret_access_key: "sts-secret",
              security_token: "sts-token",
              source: :sts,
              expires_at: %DateTime{}
            }} =
             AssumeRole.resolve(
               profile: "dev",
               home_dir: home,
               endpoint: base,
               bypass_cache: true
             )
  end
end
