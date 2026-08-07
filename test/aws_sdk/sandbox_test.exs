defmodule AwsSdk.SandboxTest do
  use ExUnit.Case, async: true

  alias AwsSdk.Sandbox

  @registry :aws_sandbox_core_test

  describe "apply/5 exact keys" do
    test "applies the function registered under a matching binary key" do
      Sandbox.register(@registry, __MODULE__, :get_thing, [
        {"alice", fn -> {:ok, :alice} end}
      ])

      binding = [name: "alice", opts: []]

      assert {:ok, :alice} = Sandbox.apply(@registry, __MODULE__, :get_thing, "alice", binding)
    end

    test "applies the function at its own arity, values in declaration order" do
      Sandbox.register(@registry, __MODULE__, :arity_thing, [
        {"g", fn group, stream, opts -> {group, stream, opts[:limit]} end}
      ])

      binding = [group: "g", stream: "s", opts: [limit: 5]]

      assert {"g", "s", 5} = Sandbox.apply(@registry, __MODULE__, :arity_thing, "g", binding)
    end
  end

  describe "apply/5 wildcard" do
    test "a :* registration matches a keyed call" do
      Sandbox.register(@registry, __MODULE__, :wild_thing, [
        {:*, fn name -> {:wildcard, name} end}
      ])

      binding = [name: "anything", opts: []]

      assert {:wildcard, "anything"} =
               Sandbox.apply(@registry, __MODULE__, :wild_thing, "anything", binding)
    end

    test "an exact key wins over a :* registration" do
      Sandbox.register(@registry, __MODULE__, :precedence_thing, [
        {"alice", fn -> :exact end},
        {:*, fn -> :wildcard end}
      ])

      binding = [name: "alice", opts: []]

      assert :exact = Sandbox.apply(@registry, __MODULE__, :precedence_thing, "alice", binding)
    end

    test "a bare function registers under :*" do
      Sandbox.register(@registry, __MODULE__, :bare_thing, [fn -> :bare end])

      binding = [opts: []]

      assert :bare = Sandbox.apply(@registry, __MODULE__, :bare_thing, :*, binding)
    end
  end

  describe "apply/5 patterns" do
    test "a Regex key matches a binary lookup key" do
      Sandbox.register(@registry, __MODULE__, :regex_thing, [
        {~r/^prod-/, fn name -> {:matched, name} end}
      ])

      binding = [name: "prod-api", opts: []]

      assert {:matched, "prod-api"} =
               Sandbox.apply(@registry, __MODULE__, :regex_thing, "prod-api", binding)
    end

    test "the pattern step is skipped when the key is :*, so Regex.match?/2 never sees an atom" do
      Sandbox.register(@registry, __MODULE__, :regex_skip_thing, [
        {~r/^prod-/, fn -> :matched end}
      ])

      binding = [opts: []]

      assert_raise RuntimeError, ~r/Function not found/, fn ->
        Sandbox.apply(@registry, __MODULE__, :regex_skip_thing, :*, binding)
      end
    end
  end

  describe "apply/5 invalid keys" do
    test "nil is not a valid key" do
      Sandbox.register(@registry, __MODULE__, :nil_thing, [fn -> :ok end])

      binding = [name: nil, opts: []]

      assert_raise FunctionClauseError, fn ->
        Sandbox.apply(@registry, __MODULE__, :nil_thing, nil, binding)
      end
    end
  end

  describe "apply/5 raises" do
    test "raises when no function matches, naming the function and key" do
      Sandbox.register(@registry, __MODULE__, :miss_thing, [{"alice", fn -> :ok end}])

      binding = [name: "bob", opts: []]

      assert_raise RuntimeError, ~r/Function not found/, fn ->
        Sandbox.apply(@registry, __MODULE__, :miss_thing, "bob", binding)
      end
    end

    test "raises when the registered function's arity exceeds the binding" do
      Sandbox.register(@registry, __MODULE__, :arity_miss, [
        {"a", fn _one, _two, _three -> :ok end}
      ])

      binding = [name: "a", opts: []]

      assert_raise RuntimeError, ~r/signature is not supported/, fn ->
        Sandbox.apply(@registry, __MODULE__, :arity_miss, "a", binding)
      end
    end

    test "raises when a registered value is not a function" do
      Sandbox.register(@registry, __MODULE__, :not_a_fun, [{"a", :not_a_function}])

      binding = [name: "a", opts: []]

      assert_raise RuntimeError, ~r/Unrecognized input/, fn ->
        Sandbox.apply(@registry, __MODULE__, :not_a_fun, "a", binding)
      end
    end
  end

  describe "register/4" do
    test "registering a second function leaves the first in place" do
      Sandbox.register(@registry, __MODULE__, :additive_one, [{"a", fn -> :one end}])
      Sandbox.register(@registry, __MODULE__, :additive_two, [{"b", fn -> :two end}])

      assert :one = Sandbox.apply(@registry, __MODULE__, :additive_one, "a", opts: [])
      assert :two = Sandbox.apply(@registry, __MODULE__, :additive_two, "b", opts: [])
    end

    test "registering the same key twice replaces the earlier function" do
      Sandbox.register(@registry, __MODULE__, :replace_thing, [{"a", fn -> :first end}])
      Sandbox.register(@registry, __MODULE__, :replace_thing, [{"a", fn -> :second end}])

      assert :second = Sandbox.apply(@registry, __MODULE__, :replace_thing, "a", opts: [])
    end
  end
end
