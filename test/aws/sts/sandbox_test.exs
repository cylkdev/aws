defmodule AWS.STS.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.STS
  alias AWS.STS.Sandbox

  @sandbox_opts [sandbox: [enabled: true]]

  describe "get_caller_identity/1" do
    test "returns mocked success" do
      Sandbox.set_get_caller_identity_responses([
        fn ->
          {:ok,
           %{
             account: "123456789012",
             arn: "arn:aws:iam::123456789012:user/alice",
             user_id: "AIDA123"
           }}
        end
      ])

      assert {:ok,
              %{
                account: "123456789012",
                arn: "arn:aws:iam::123456789012:user/alice",
                user_id: "AIDA123"
              }} = STS.get_caller_identity(@sandbox_opts)
    end

    test "supports arity-1 function receiving opts" do
      Sandbox.set_get_caller_identity_responses([
        fn opts -> {:ok, %{account: "x", arn: "y", user_id: "z", opts: opts}} end
      ])

      assert {:ok, %{opts: opts}} = STS.get_caller_identity(@sandbox_opts)
      assert opts[:sandbox] === [enabled: true]
    end

    test "returns mocked error" do
      Sandbox.set_get_caller_identity_responses([
        fn -> {:error, :boom} end
      ])

      assert {:error, :boom} = STS.get_caller_identity(@sandbox_opts)
    end
  end
end
