defmodule AWS.Credentials.Providers.StaticProfileTest do
  use ExUnit.Case, async: true

  alias AWS.Credentials.Providers.StaticProfile
  alias AWS.CredentialsFixtures

  @tag :tmp_dir
  test "returns static creds from the profile", %{tmp_dir: tmp} do
    home =
      CredentialsFixtures.build_home(tmp,
        credentials: """
        [default]
        aws_access_key_id = AKIA
        aws_secret_access_key = SECRET
        aws_session_token = TOKEN
        """
      )

    assert {:ok,
            %{
              access_key_id: "AKIA",
              secret_access_key: "SECRET",
              security_token: "TOKEN",
              source: :profile
            }} = StaticProfile.resolve(profile: "default", home_dir: home)
  end

  @tag :tmp_dir
  test "skips profiles that carry SSO indicators", %{tmp_dir: tmp} do
    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        sso_session = main
        sso_account_id = 111
        sso_role_name = Admin
        """
      )

    assert :skip = StaticProfile.resolve(profile: "dev", home_dir: home)
  end

  @tag :tmp_dir
  test "skips when profile has no static keys", %{tmp_dir: tmp} do
    home =
      CredentialsFixtures.build_home(tmp,
        config: """
        [profile dev]
        region = us-east-1
        """
      )

    assert :skip = StaticProfile.resolve(profile: "dev", home_dir: home)
  end

  @tag :tmp_dir
  test "skips when profile is absent", %{tmp_dir: tmp} do
    home = CredentialsFixtures.build_home(tmp, config: "")
    assert :skip = StaticProfile.resolve(profile: "missing", home_dir: home)
  end
end
