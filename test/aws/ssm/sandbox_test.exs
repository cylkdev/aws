defmodule AWS.SSM.SandboxTest do
  use ExUnit.Case, async: true

  alias AWS.SSM
  alias AWS.SSM.Sandbox

  @sandbox_opts [sandbox: [enabled: true]]

  describe "get_parameter/2" do
    test "returns mocked parameter" do
      Sandbox.set_get_parameter_responses([
        {"/app/db/host",
         fn ->
           {:ok,
            %{
              parameter: %{
                name: "/app/db/host",
                type: "String",
                value: "db.internal",
                version: 1
              }
            }}
         end}
      ])

      assert {:ok, %{parameter: %{value: "db.internal", version: 1}}} =
               SSM.get_parameter("/app/db/host", @sandbox_opts)
    end

    test "threads with_decryption opt through to the sandbox function" do
      Sandbox.set_get_parameter_responses([
        {"/app/db/password",
         fn opts ->
           assert Keyword.get(opts, :with_decryption) == true

           {:ok,
            %{parameter: %{name: "/app/db/password", value: "hunter2", type: "SecureString"}}}
         end}
      ])

      assert {:ok, %{parameter: %{value: "hunter2"}}} =
               SSM.get_parameter("/app/db/password", [
                 {:with_decryption, true} | @sandbox_opts
               ])
    end
  end

  describe "get_parameters/2" do
    test "returns mocked parameters by names list" do
      Sandbox.set_get_parameters_responses([
        fn names ->
          {:ok,
           %{
             parameters: Enum.map(names, fn n -> %{name: n, value: "v-#{n}"} end),
             invalid_parameters: []
           }}
        end
      ])

      assert {:ok, %{parameters: [%{name: "/a"}, %{name: "/b"}], invalid_parameters: []}} =
               SSM.get_parameters(["/a", "/b"], @sandbox_opts)
    end
  end

  describe "get_parameters_by_path/2" do
    test "returns mocked parameters under a path" do
      Sandbox.set_get_parameters_by_path_responses([
        {"/app/", fn -> {:ok, %{parameters: [%{name: "/app/db/host"}], next_token: nil}} end}
      ])

      assert {:ok, %{parameters: [%{name: "/app/db/host"}], next_token: nil}} =
               SSM.get_parameters_by_path("/app/", [{:recursive, true} | @sandbox_opts])
    end

    test "threads next_token through to the sandbox function" do
      Sandbox.set_get_parameters_by_path_responses([
        {"/app/",
         fn opts ->
           assert Keyword.get(opts, :next_token) == "abc"
           {:ok, %{parameters: [], next_token: nil}}
         end}
      ])

      assert {:ok, %{parameters: [], next_token: nil}} =
               SSM.get_parameters_by_path("/app/", [{:next_token, "abc"} | @sandbox_opts])
    end
  end

  describe "put_parameter/3" do
    test "writes a String parameter and returns the version" do
      Sandbox.set_put_parameter_responses([
        {"/app/feature_flag", fn -> {:ok, %{version: 1, tier: "Standard"}} end}
      ])

      assert {:ok, %{version: 1, tier: "Standard"}} =
               SSM.put_parameter("/app/feature_flag", "on", [{:type, "String"} | @sandbox_opts])
    end

    test "passes SecureString type and key_id through to the sandbox function" do
      Sandbox.set_put_parameter_responses([
        {"/app/db/password",
         fn value, opts ->
           assert value == "hunter2"
           assert Keyword.get(opts, :type) == "SecureString"
           assert Keyword.get(opts, :key_id) == "alias/aws/ssm"
           {:ok, %{version: 1, tier: "Standard"}}
         end}
      ])

      assert {:ok, %{version: 1}} =
               SSM.put_parameter("/app/db/password", "hunter2", [
                 {:type, "SecureString"},
                 {:key_id, "alias/aws/ssm"} | @sandbox_opts
               ])
    end
  end

  describe "delete_parameter/2" do
    test "returns success" do
      Sandbox.set_delete_parameter_responses([
        {"/app/db/host", fn -> {:ok, %{}} end}
      ])

      assert {:ok, %{}} = SSM.delete_parameter("/app/db/host", @sandbox_opts)
    end
  end

  describe "delete_parameters/2" do
    test "returns mocked deleted + invalid lists" do
      Sandbox.set_delete_parameters_responses([
        fn names ->
          {:ok, %{deleted_parameters: names, invalid_parameters: []}}
        end
      ])

      assert {:ok, %{deleted_parameters: ["/a", "/b"], invalid_parameters: []}} =
               SSM.delete_parameters(["/a", "/b"], @sandbox_opts)
    end
  end

  describe "describe_parameters/1" do
    test "returns mocked parameter metadata" do
      Sandbox.set_describe_parameters_responses([
        fn ->
          {:ok,
           %{
             parameters: [%{name: "/app/db/host", type: "String"}],
             next_token: nil
           }}
        end
      ])

      assert {:ok, %{parameters: [%{name: "/app/db/host"}], next_token: nil}} =
               SSM.describe_parameters(@sandbox_opts)
    end
  end

  describe "describe_instance_information/1" do
    test "returns mocked managed node information" do
      Sandbox.set_describe_instance_information_responses([
        fn ->
          {:ok,
           %{
             instance_information_list: [
               %{
                 instance_id: "i-1234567890abcdef0",
                 ping_status: "Online",
                 platform_type: "Linux"
               }
             ],
             next_token: nil
           }}
        end
      ])

      assert {:ok,
              %{
                instance_information_list: [%{instance_id: "i-1234567890abcdef0"}],
                next_token: nil
              }} = SSM.describe_instance_information(@sandbox_opts)
    end

    test "threads filters opt through to the sandbox function" do
      Sandbox.set_describe_instance_information_responses([
        fn opts ->
          assert Keyword.get(opts, :filters) == [%{"Key" => "PingStatus", "Values" => ["Online"]}]
          {:ok, %{instance_information_list: [], next_token: nil}}
        end
      ])

      assert {:ok, %{instance_information_list: [], next_token: nil}} =
               SSM.describe_instance_information([
                 {:filters, [%{"Key" => "PingStatus", "Values" => ["Online"]}]} | @sandbox_opts
               ])
    end
  end

  describe "regex matching" do
    test "matches parameter name by regex" do
      Sandbox.set_get_parameter_responses([
        {~r|^/app/|, fn -> {:ok, %{parameter: %{value: "matched"}}} end}
      ])

      assert {:ok, %{parameter: %{value: "matched"}}} =
               SSM.get_parameter("/app/anything", @sandbox_opts)
    end
  end
end
