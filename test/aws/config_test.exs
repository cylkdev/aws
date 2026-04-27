defmodule AWS.ConfigTest do
  use ExUnit.Case, async: false

  alias AWS.AuthCache
  alias AWS.Config

  @env_keys [
    "AWS_PROFILE",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_SESSION_TOKEN",
    "AWS_REGION",
    "AWS_DEFAULT_REGION"
  ]

  @app_env_keys [:access_key_id, :secret_access_key, :security_token, :region, :sandbox]

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

  describe "literals" do
    test "binary chains pass through as the literal" do
      Application.put_env(:aws, :access_key_id, "AKIA_LITERAL")
      Application.put_env(:aws, :secret_access_key, "secret_literal")
      Application.put_env(:aws, :region, "us-east-1")

      resolved = Config.new()

      assert resolved[:access_key_id] === "AKIA_LITERAL"
      assert resolved[:secret_access_key] === "secret_literal"
      assert resolved[:region] === "us-east-1"
    end
  end

  describe "{:system, _} sources" do
    test "reads from the environment when set" do
      System.put_env("AWS_TEST_ID", "FROM_ENV")
      on_exit(fn -> System.delete_env("AWS_TEST_ID") end)

      Application.put_env(:aws, :access_key_id, {:system, "AWS_TEST_ID"})

      assert Config.access_key_id() === "FROM_ENV"
    end

    test "yields nil when the env var is unset, falling through a list" do
      Application.put_env(:aws, :access_key_id, [
        {:system, "AWS_TEST_MISSING"},
        "fallback_literal"
      ])

      assert Config.access_key_id() === "fallback_literal"
    end

    test "treats empty-string env var as missing" do
      System.put_env("AWS_TEST_EMPTY", "")
      on_exit(fn -> System.delete_env("AWS_TEST_EMPTY") end)

      Application.put_env(:aws, :access_key_id, [{:system, "AWS_TEST_EMPTY"}, "fallback"])

      assert Config.access_key_id() === "fallback"
    end

    test "trims whitespace around env values" do
      System.put_env("AWS_TEST_PADDED", "  padded  ")
      on_exit(fn -> System.delete_env("AWS_TEST_PADDED") end)

      Application.put_env(:aws, :access_key_id, {:system, "AWS_TEST_PADDED"})

      assert Config.access_key_id() === "padded"
    end
  end

  describe "list sources" do
    test "first non-nil value in the list wins" do
      Application.put_env(:aws, :access_key_id, [
        {:system, "AWS_TEST_ABSENT"},
        "first_winner",
        "second_loser"
      ])

      assert Config.access_key_id() === "first_winner"
    end

    test "unresolved creds remain nil; region falls back to 'us-east-1'" do
      resolved = Config.new()
      assert resolved[:region] === "us-east-1"
      assert is_nil(resolved[:access_key_id])
      assert is_nil(resolved[:secret_access_key])
    end
  end

  describe "map-returning sources (per-key resolution)" do
    test ":instance_role yields the requested key from IMDS creds" do
      seed_cache(:aws_instance_auth, %{
        access_key_id: "AKIA_IMDS",
        secret_access_key: "IMDS_SECRET",
        security_token: "IMDS_TOKEN"
      })

      Application.put_env(:aws, :access_key_id, :instance_role)
      Application.put_env(:aws, :secret_access_key, :instance_role)
      Application.put_env(:aws, :security_token, :instance_role)

      assert Config.access_key_id() === "AKIA_IMDS"
      assert Config.secret_access_key() === "IMDS_SECRET"
      assert Config.security_token() === "IMDS_TOKEN"
    end

    test ":ecs_task_role extracts the requested key" do
      seed_cache(:aws_ecs_auth, %{
        access_key_id: "AKIA_ECS",
        secret_access_key: "ECS_SECRET"
      })

      Application.put_env(:aws, :access_key_id, :ecs_task_role)
      Application.put_env(:aws, :secret_access_key, :ecs_task_role)

      assert Config.access_key_id() === "AKIA_ECS"
      assert Config.secret_access_key() === "ECS_SECRET"
    end

    test "{:awscli, profile, ttl} extracts creds and region from the cached profile" do
      seed_cache({:awscli, "test-profile"}, %{
        access_key_id: "AKIA_AWSCLI",
        secret_access_key: "AWSCLI_SECRET",
        security_token: "AWSCLI_TOKEN",
        region: "eu-central-1"
      })

      Application.put_env(:aws, :access_key_id, {:awscli, "test-profile", 30})
      Application.put_env(:aws, :secret_access_key, {:awscli, "test-profile", 30})
      Application.put_env(:aws, :security_token, {:awscli, "test-profile", 30})
      Application.put_env(:aws, :region, {:awscli, "test-profile", 30})

      assert Config.access_key_id() === "AKIA_AWSCLI"
      assert Config.secret_access_key() === "AWSCLI_SECRET"
      assert Config.security_token() === "AWSCLI_TOKEN"
      assert Config.region() === "eu-central-1"
    end

    test "{:awscli, {:system, var}, ttl} resolves the profile name from the env at call time" do
      seed_cache({:awscli, "from-env-profile"}, %{
        access_key_id: "AKIA_FROM_ENV",
        region: "ap-northeast-1"
      })

      Application.put_env(
        :aws,
        :access_key_id,
        {:awscli, {:system, "AWS_PROFILE"}, 30}
      )

      Application.put_env(:aws, :region, {:awscli, {:system, "AWS_PROFILE"}, 30})

      System.put_env("AWS_PROFILE", "from-env-profile")
      on_exit(fn -> System.delete_env("AWS_PROFILE") end)

      assert Config.access_key_id() === "AKIA_FROM_ENV"
      assert Config.region() === "ap-northeast-1"
    end
  end

  describe "precedence (per-call > app env > defaults)" do
    test "per-call override beats app env" do
      Application.put_env(:aws, :access_key_id, "FROM_APP_ENV")

      assert Config.access_key_id(access_key_id: "FROM_CALL") === "FROM_CALL"
    end

    test "per-call override threads through new/1" do
      Application.put_env(:aws, :access_key_id, "FROM_APP_ENV")

      resolved = Config.new(access_key_id: "FROM_CALL")
      assert resolved[:access_key_id] === "FROM_CALL"
    end

    test "app env beats built-in defaults" do
      Application.put_env(:aws, :region, "ap-southeast-2")

      assert Config.region() === "ap-southeast-2"
    end

    test "region default chain prefers AWS_REGION over AWS_DEFAULT_REGION" do
      System.put_env("AWS_REGION", "primary-region")
      System.put_env("AWS_DEFAULT_REGION", "fallback-region")

      on_exit(fn ->
        System.delete_env("AWS_REGION")
        System.delete_env("AWS_DEFAULT_REGION")
      end)

      assert Config.region() === "primary-region"
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

  describe "sandbox/1" do
    test "returns the built-in defaults with no overrides" do
      sandbox = Config.sandbox()

      assert sandbox[:enabled] === false
      assert sandbox[:mode] === :local
      assert sandbox[:scheme] === "http://"
      assert sandbox[:host] === "localhost"
      assert sandbox[:port] === 4566
    end

    test "app env overrides defaults" do
      Application.put_env(:aws, :sandbox, host: "sandbox.local", port: 9999)

      sandbox = Config.sandbox()

      assert sandbox[:host] === "sandbox.local"
      assert sandbox[:port] === 9999
      assert sandbox[:scheme] === "http://"
    end

    test "caller opts override app env" do
      Application.put_env(:aws, :sandbox, host: "from-app-env")

      sandbox = Config.sandbox(sandbox: [host: "from-call"])

      assert sandbox[:host] === "from-call"
    end
  end

  describe "new/1" do
    test "aggregates every per-key resolver" do
      Application.put_env(:aws, :access_key_id, "AK")
      Application.put_env(:aws, :secret_access_key, "SK")
      Application.put_env(:aws, :security_token, "ST")
      Application.put_env(:aws, :region, "us-west-1")

      resolved = Config.new()

      assert resolved[:access_key_id] === "AK"
      assert resolved[:secret_access_key] === "SK"
      assert resolved[:security_token] === "ST"
      assert resolved[:region] === "us-west-1"
      assert is_list(resolved[:sandbox])
      assert resolved[:sandbox][:enabled] === false
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
