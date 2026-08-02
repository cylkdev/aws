defmodule AWS.ConfigTest do
  use ExUnit.Case, async: false

  alias AWS.AuthCache
  alias AWS.Config

  setup do
    # Each test starts with a clean slate: no env creds, no app-env creds,
    # and no cached IMDS/ECS/awscli entries. Anything we observe then comes
    # from the per-call opts we're testing.
    env_keys = [
      "AWS_PROFILE",
      "AWS_ACCESS_KEY_ID",
      "AWS_SECRET_ACCESS_KEY",
      "AWS_SESSION_TOKEN",
      "AWS_REGION",
      "AWS_DEFAULT_REGION"
    ]

    app_env_keys = [:access_key_id, :secret_access_key, :security_token, :region, :sandbox]

    prior_env = Enum.map(env_keys, &{&1, System.get_env(&1)})
    prior_app_env = Enum.map(app_env_keys, &{&1, Application.get_env(:aws, &1)})

    for var <- env_keys, do: System.delete_env(var)
    for key <- app_env_keys, do: Application.delete_env(:aws, key)

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

      assert "AKIA_LITERAL" === resolved[:access_key_id]
      assert "secret_literal" === resolved[:secret_access_key]
      assert "us-east-1" === resolved[:region]
    end
  end

  describe "{:system, _} sources" do
    test "reads from the environment when set" do
      System.put_env("AWS_TEST_ID", "FROM_ENV")
      on_exit(fn -> System.delete_env("AWS_TEST_ID") end)

      Application.put_env(:aws, :access_key_id, {:system, "AWS_TEST_ID"})

      assert "FROM_ENV" === Config.access_key_id()
    end

    test "yields nil when the env var is unset, falling through a list" do
      Application.put_env(:aws, :access_key_id, [
        {:system, "AWS_TEST_MISSING"},
        "fallback_literal"
      ])

      assert "fallback_literal" === Config.access_key_id()
    end

    test "treats empty-string env var as missing" do
      System.put_env("AWS_TEST_EMPTY", "")
      on_exit(fn -> System.delete_env("AWS_TEST_EMPTY") end)

      Application.put_env(:aws, :access_key_id, [{:system, "AWS_TEST_EMPTY"}, "fallback"])

      assert "fallback" === Config.access_key_id()
    end

    test "trims whitespace around env values" do
      System.put_env("AWS_TEST_PADDED", "  padded  ")
      on_exit(fn -> System.delete_env("AWS_TEST_PADDED") end)

      Application.put_env(:aws, :access_key_id, {:system, "AWS_TEST_PADDED"})

      assert "padded" === Config.access_key_id()
    end
  end

  describe "list sources" do
    test "first non-nil value in the list wins" do
      Application.put_env(:aws, :access_key_id, [
        {:system, "AWS_TEST_ABSENT"},
        "first_winner",
        "second_loser"
      ])

      assert "first_winner" === Config.access_key_id()
    end

    test "unresolved creds remain nil; region falls back to 'us-east-1'" do
      resolved = Config.new()
      assert "us-east-1" === resolved[:region]
      assert is_nil(resolved[:access_key_id])
      assert is_nil(resolved[:secret_access_key])
    end
  end

  describe "map-returning sources (per-key resolution)" do
  end

  describe "precedence (per-call > app env > defaults)" do
    test "per-call override beats app env" do
      Application.put_env(:aws, :access_key_id, "FROM_APP_ENV")

      assert "FROM_CALL" === Config.access_key_id(access_key_id: "FROM_CALL")
    end

    test "per-call override threads through new/1" do
      Application.put_env(:aws, :access_key_id, "FROM_APP_ENV")

      resolved = Config.new(access_key_id: "FROM_CALL")
      assert "FROM_CALL" === resolved[:access_key_id]
    end

    test "app env beats built-in defaults" do
      Application.put_env(:aws, :region, "ap-southeast-2")

      assert "ap-southeast-2" === Config.region()
    end

    test "region default chain prefers AWS_REGION over AWS_DEFAULT_REGION" do
      System.put_env("AWS_REGION", "primary-region")
      System.put_env("AWS_DEFAULT_REGION", "fallback-region")

      on_exit(fn ->
        System.delete_env("AWS_REGION")
        System.delete_env("AWS_DEFAULT_REGION")
      end)

      assert "primary-region" === Config.region()
    end
  end

  describe "per-call :profile" do
    test "a blank or nil profile falls back to the normal chain" do
      Application.put_env(:aws, :access_key_id, "AKIA_FROM_APP_ENV")

      assert "AKIA_FROM_APP_ENV" === Config.access_key_id(profile: "")
      assert "AKIA_FROM_APP_ENV" === Config.access_key_id(profile: nil)
    end
  end

  describe "{:awscli, profile} two-tuple source" do
  end

  describe "region/1" do
    test "uses the env chain when no opts are supplied" do
      System.put_env("AWS_REGION", "sa-east-1")
      on_exit(fn -> System.delete_env("AWS_REGION") end)

      assert "sa-east-1" === Config.region()
    end

    test "respects an explicit opts override" do
      assert "us-west-2" === Config.region(region: "us-west-2")
    end

    test "falls back to 'us-east-1' when everything is unset" do
      assert "us-east-1" === Config.region()
    end
  end

  describe "sandbox/1" do
    test "returns the built-in defaults with no overrides" do
      sandbox = Config.sandbox()

      assert false === sandbox[:enabled]
    end

    test "app env overrides defaults" do
      Application.put_env(:aws, :sandbox, enabled: true)

      assert true === Config.sandbox()[:enabled]
    end

    test "caller opts override app env" do
      Application.put_env(:aws, :sandbox, enabled: false)

      assert true === Config.sandbox(sandbox: [enabled: true])[:enabled]
    end
  end

  describe "new/1" do
  end

  # ---------------------------------------------------------------------------
end
