defmodule AWS.ConfigTest do
  use ExUnit.Case, async: false

  alias AWS.AuthCache
  alias AWS.Config

  @env_keys [
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_SESSION_TOKEN",
    "AWS_REGION",
    "AWS_DEFAULT_REGION"
  ]

  @app_env_keys [:access_key_id, :secret_access_key, :security_token, :region]

  setup do
    # Each test starts with a clean slate: no env creds, no app-env creds,
    # and no cached IMDS/ECS/awscli entries. Anything we observe then comes
    # from the per-call opts we're testing.
    prior_env = Enum.map(@env_keys, &{&1, System.get_env(&1)})
    prior_app_env = Enum.map(@app_env_keys, &{&1, Application.get_env(:aws, &1)})

    for var <- @env_keys, do: System.delete_env(var)
    for key <- @app_env_keys, do: Application.delete_env(:aws, key)

    AuthCache.invalidate(:aws_instance_auth)
    AuthCache.invalidate(:aws_ecs_auth)

    on_exit(fn ->
      for {var, value} <- prior_env do
        if value, do: System.put_env(var, value), else: System.delete_env(var)
      end

      for {key, value} <- prior_app_env do
        if is_nil(value),
          do: Application.delete_env(:aws, key),
          else: Application.put_env(:aws, key, value)
      end

      AuthCache.invalidate(:aws_instance_auth)
      AuthCache.invalidate(:aws_ecs_auth)
    end)

    :ok
  end

  describe "sandbox_credentials/0" do
    test "returns static test credentials including a session token" do
      assert Config.sandbox_credentials() === [
               access_key_id: "test",
               secret_access_key: "test",
               security_token: "test"
             ]
    end
  end

  describe "put_sandbox_credentials/1" do
    test "seeds static test creds without overwriting caller-supplied keys" do
      merged = Config.put_sandbox_credentials(access_key_id: "caller-wins")

      assert merged[:access_key_id] === "caller-wins"
      assert merged[:secret_access_key] === "test"
      assert merged[:security_token] === "test"
    end
  end

  describe "new/2 literals" do
    test "passes literal binaries through unchanged" do
      resolved =
        Config.new(:s3,
          access_key_id: "AKIA_LITERAL",
          secret_access_key: "secret_literal",
          region: "us-east-1"
        )

      assert resolved.access_key_id === "AKIA_LITERAL"
      assert resolved.secret_access_key === "secret_literal"
      assert resolved.region === "us-east-1"
    end
  end

  describe "new/2 {:system, _} sources" do
    test "reads from the environment when set" do
      System.put_env("AWS_TEST_ID", "FROM_ENV")
      on_exit(fn -> System.delete_env("AWS_TEST_ID") end)

      resolved = Config.new(:s3, access_key_id: {:system, "AWS_TEST_ID"})
      assert resolved.access_key_id === "FROM_ENV"
    end

    test "yields nil when the env var is unset, falling through a list" do
      resolved =
        Config.new(:s3,
          access_key_id: [{:system, "AWS_TEST_MISSING"}, "fallback_literal"]
        )

      assert resolved.access_key_id === "fallback_literal"
    end

    test "treats empty-string env var as missing" do
      System.put_env("AWS_TEST_EMPTY", "")
      on_exit(fn -> System.delete_env("AWS_TEST_EMPTY") end)

      resolved =
        Config.new(:s3,
          access_key_id: [{:system, "AWS_TEST_EMPTY"}, "fallback"]
        )

      assert resolved.access_key_id === "fallback"
    end
  end

  describe "new/2 list sources" do
    test "first non-nil value in the list wins" do
      resolved =
        Config.new(:s3,
          access_key_id: [{:system, "AWS_TEST_ABSENT"}, "first_winner", "second_loser"]
        )

      assert resolved.access_key_id === "first_winner"
    end

    test "unresolved creds remain nil; region falls back to 'us-east-1'" do
      resolved = Config.new(:s3, [])
      assert resolved.region === "us-east-1"
      assert is_nil(resolved.access_key_id)
      assert is_nil(resolved.secret_access_key)
    end
  end

  describe "new/2 map-returning sources (outer-merge)" do
    test ":instance_role populates all three cred fields" do
      seed_cache(:aws_instance_auth, %{
        access_key_id: "AKIA_IMDS",
        secret_access_key: "IMDS_SECRET",
        security_token: "IMDS_TOKEN"
      })

      resolved = Config.new(:s3, access_key_id: :instance_role)

      assert resolved.access_key_id === "AKIA_IMDS"
      assert resolved.secret_access_key === "IMDS_SECRET"
      assert resolved.security_token === "IMDS_TOKEN"
    end

    test ":ecs_task_role populates via outer-merge" do
      seed_cache(:aws_ecs_auth, %{
        access_key_id: "AKIA_ECS",
        secret_access_key: "ECS_SECRET",
        security_token: "ECS_TOKEN"
      })

      resolved = Config.new(:s3, access_key_id: :ecs_task_role)

      assert resolved.access_key_id === "AKIA_ECS"
      assert resolved.secret_access_key === "ECS_SECRET"
    end

    test "{:awscli, profile, ttl} populates creds and region from the profile" do
      seed_cache({:awscli, "test-profile"}, %{
        access_key_id: "AKIA_AWSCLI",
        secret_access_key: "AWSCLI_SECRET",
        security_token: "AWSCLI_TOKEN",
        region: "eu-central-1"
      })

      resolved =
        Config.new(:s3,
          access_key_id: {:awscli, "test-profile", 30},
          region: {:awscli, "test-profile", 30}
        )

      assert resolved.access_key_id === "AKIA_AWSCLI"
      assert resolved.secret_access_key === "AWSCLI_SECRET"
      assert resolved.security_token === "AWSCLI_TOKEN"
      assert resolved.region === "eu-central-1"
    end
  end

  describe "new/2 precedence (per-call > app env > defaults)" do
    test "per-call override beats app env" do
      Application.put_env(:aws, :access_key_id, "FROM_APP_ENV")
      resolved = Config.new(:s3, access_key_id: "FROM_CALL")
      assert resolved.access_key_id === "FROM_CALL"
    end

    test "app env beats built-in defaults" do
      Application.put_env(:aws, :region, "ap-southeast-2")
      resolved = Config.new(:s3, [])
      assert resolved.region === "ap-southeast-2"
    end

    test "region default chain prefers AWS_REGION over AWS_DEFAULT_REGION" do
      System.put_env("AWS_REGION", "primary-region")
      System.put_env("AWS_DEFAULT_REGION", "fallback-region")

      on_exit(fn ->
        System.delete_env("AWS_REGION")
        System.delete_env("AWS_DEFAULT_REGION")
      end)

      resolved = Config.new(:s3, [])
      assert resolved.region === "primary-region"
    end
  end

  describe "region/1" do
    test "uses the env chain when no opts are supplied" do
      System.put_env("AWS_REGION", "sa-east-1")
      on_exit(fn -> System.delete_env("AWS_REGION") end)

      assert Config.region() === "sa-east-1"
    end

    test "respects an explicit opts override" do
      assert Config.region(region: "us-west-2") === "us-west-2"
    end

    test "falls back to 'us-east-1' when everything is unset" do
      assert Config.region() === "us-east-1"
    end
  end

  # ---------------------------------------------------------------------------

  defp seed_cache(key, creds) do
    entry = %{
      creds: creds,
      expires_at: nil,
      cached_at: System.monotonic_time(:second)
    }

    # Go through the GenServer so the insert is serialized against any
    # concurrent refresh, just like the production path.
    GenServer.call(AuthCache, {:put, key, entry})
    on_exit(fn -> AuthCache.invalidate(key) end)
  end
end
