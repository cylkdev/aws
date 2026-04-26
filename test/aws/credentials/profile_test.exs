defmodule AWS.Credentials.ProfileTest do
  use ExUnit.Case

  alias AWS.Credentials.Profile
  alias AWS.CredentialsFixtures

  describe "load/2" do
    @tag :tmp_dir
    test "merges ~/.aws/config and ~/.aws/credentials for the default profile", %{tmp_dir: tmp} do
      home =
        CredentialsFixtures.build_home(tmp,
          config: """
          [default]
          region = us-east-2
          """,
          credentials: """
          [default]
          aws_access_key_id = AKIA
          aws_secret_access_key = SECRET
          """
        )

      assert Profile.load("default", home_dir: home) === %{
               "region" => "us-east-2",
               "aws_access_key_id" => "AKIA",
               "aws_secret_access_key" => "SECRET"
             }
    end

    @tag :tmp_dir
    test "reads [profile NAME] for non-default profiles in ~/.aws/config", %{tmp_dir: tmp} do
      home =
        CredentialsFixtures.build_home(tmp,
          config: """
          [profile dev]
          region = us-west-2
          sso_session = main
          """
        )

      assert Profile.load("dev", home_dir: home) === %{
               "region" => "us-west-2",
               "sso_session" => "main"
             }
    end

    @tag :tmp_dir
    test "credentials file wins when both files define the same key", %{tmp_dir: tmp} do
      home =
        CredentialsFixtures.build_home(tmp,
          config: """
          [profile dev]
          aws_access_key_id = FROM_CONFIG
          """,
          credentials: """
          [dev]
          aws_access_key_id = FROM_CREDENTIALS
          """
        )

      assert %{"aws_access_key_id" => "FROM_CREDENTIALS"} = Profile.load("dev", home_dir: home)
    end

    @tag :tmp_dir
    test "returns nil when the profile is absent from both files", %{tmp_dir: tmp} do
      home = CredentialsFixtures.build_home(tmp, config: "[default]\n")
      assert Profile.load("missing", home_dir: home) === nil
    end
  end

  describe "load_sso_session/2" do
    @tag :tmp_dir
    test "returns sso-session blocks from ~/.aws/config", %{tmp_dir: tmp} do
      home =
        CredentialsFixtures.build_home(tmp,
          config: """
          [sso-session main]
          sso_start_url = https://example.awsapps.com/start
          sso_region = us-east-1
          sso_registration_scopes = sso:account:access
          """
        )

      assert Profile.load_sso_session("main", home_dir: home) === %{
               "sso_start_url" => "https://example.awsapps.com/start",
               "sso_region" => "us-east-1",
               "sso_registration_scopes" => "sso:account:access"
             }
    end

    @tag :tmp_dir
    test "returns nil when the session does not exist", %{tmp_dir: tmp} do
      home = CredentialsFixtures.build_home(tmp, config: "")
      assert Profile.load_sso_session("missing", home_dir: home) === nil
    end
  end

  describe "default/0" do
    test "prefers AWS_PROFILE, then AWS_DEFAULT_PROFILE, then \"default\"" do
      System.delete_env("AWS_PROFILE")
      System.delete_env("AWS_DEFAULT_PROFILE")
      assert Profile.default() === "default"

      System.put_env("AWS_DEFAULT_PROFILE", "fallback")
      assert Profile.default() === "fallback"

      System.put_env("AWS_PROFILE", "primary")
      assert Profile.default() === "primary"
    after
      System.delete_env("AWS_PROFILE")
      System.delete_env("AWS_DEFAULT_PROFILE")
    end
  end
end
