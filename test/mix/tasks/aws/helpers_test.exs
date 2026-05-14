defmodule Mix.Tasks.AWS.HelpersTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.AWS.Helpers

  describe "extract_filters/1" do
    test "splits --filter-foo=bar out of argv" do
      assert {["--name", "x"], [foo: ["bar"]]} =
               Helpers.extract_filters(["--filter-foo=bar", "--name", "x"])
    end

    test "accepts space-separated value" do
      assert {["--name", "x"], [foo: ["bar"]]} =
               Helpers.extract_filters(["--filter-foo", "bar", "--name", "x"])
    end

    test "kebab-case field names become snake_case atoms" do
      assert {[], [lifecycle_state: ["Pending:Wait"]]} =
               Helpers.extract_filters(["--filter-lifecycle-state=Pending:Wait"])
    end

    test "repeated same key OR-combines values" do
      assert {[], [status: ["A", "B", "C"]]} =
               Helpers.extract_filters([
                 "--filter-status=A",
                 "--filter-status=B",
                 "--filter-status=C"
               ])
    end

    test "different keys preserved as separate entries (AND at apply time)" do
      assert {[], filters} =
               Helpers.extract_filters([
                 "--filter-status=A",
                 "--filter-region=us-east-1"
               ])

      assert filters[:status] == ["A"]
      assert filters[:region] == ["us-east-1"]
    end

    test "no filter flags returns argv unchanged and empty filters" do
      assert {["--name", "x", "--region", "us-east-1"], []} =
               Helpers.extract_filters(["--name", "x", "--region", "us-east-1"])
    end

    test "raises when value is missing" do
      assert_raise Mix.Error, ~r/--filter-foo/, fn ->
        Helpers.extract_filters(["--filter-foo"])
      end
    end

    test "raises when next arg is another flag (treats as missing value)" do
      assert_raise Mix.Error, ~r/--filter-foo/, fn ->
        Helpers.extract_filters(["--filter-foo", "--bar"])
      end
    end
  end

  describe "apply_filters/2" do
    test "no filters passes through" do
      assert {:ok, %{a: [1, 2]}} = Helpers.apply_filters({:ok, %{a: [1, 2]}}, [])
    end

    test "error tuple passes through" do
      assert {:error, :nope} = Helpers.apply_filters({:error, :nope}, foo: ["bar"])
    end

    test "filters list of maps where the field appears" do
      response = %{
        instances: [
          %{instance_id: "a", lifecycle_state: "InService"},
          %{instance_id: "b", lifecycle_state: "Pending:Wait"},
          %{instance_id: "c", lifecycle_state: "InService"}
        ]
      }

      assert {:ok, %{instances: [%{instance_id: "b"}]}} =
               Helpers.apply_filters({:ok, response}, lifecycle_state: ["Pending:Wait"])
    end

    test "leaves lists alone where the field does not appear" do
      response = %{
        groups: [%{name: "g1", instances: []}, %{name: "g2", instances: []}]
      }

      # `lifecycle_state` is not on group elements, so groups list passes through
      assert {:ok, %{groups: [_, _]}} =
               Helpers.apply_filters({:ok, response}, lifecycle_state: ["X"])
    end

    test "filters at nested depth (instances inside groups)" do
      response = %{
        auto_scaling_groups: [
          %{
            auto_scaling_group_name: "my-asg",
            instances: [
              %{instance_id: "a", lifecycle_state: "InService"},
              %{instance_id: "b", lifecycle_state: "Pending:Wait"}
            ]
          }
        ]
      }

      assert {:ok,
              %{
                auto_scaling_groups: [
                  %{
                    auto_scaling_group_name: "my-asg",
                    instances: [%{instance_id: "b", lifecycle_state: "Pending:Wait"}]
                  }
                ]
              }} =
               Helpers.apply_filters({:ok, response}, lifecycle_state: ["Pending:Wait"])
    end

    test "OR within a key" do
      response = %{
        items: [
          %{status: "A"},
          %{status: "B"},
          %{status: "C"}
        ]
      }

      assert {:ok, %{items: [%{status: "A"}, %{status: "C"}]}} =
               Helpers.apply_filters({:ok, response}, status: ["A", "C"])
    end

    test "AND across keys" do
      response = %{
        items: [
          %{status: "A", region: "us-east-1"},
          %{status: "A", region: "eu-west-1"},
          %{status: "B", region: "us-east-1"}
        ]
      }

      assert {:ok, %{items: [%{status: "A", region: "us-east-1"}]}} =
               Helpers.apply_filters(
                 {:ok, response},
                 status: ["A"],
                 region: ["us-east-1"]
               )
    end

    test "stringifies values for comparison (works with int / bool / atom)" do
      response = %{
        items: [
          %{count: 1, healthy: true, kind: :primary},
          %{count: 2, healthy: false, kind: :replica}
        ]
      }

      assert {:ok, %{items: [%{count: 1}]}} =
               Helpers.apply_filters({:ok, response}, count: ["1"])

      assert {:ok, %{items: [%{healthy: false}]}} =
               Helpers.apply_filters({:ok, response}, healthy: ["false"])

      assert {:ok, %{items: [%{kind: :primary}]}} =
               Helpers.apply_filters({:ok, response}, kind: ["primary"])
    end

    test "filter applies independently at each list where the field appears" do
      response = %{
        groups_a: [%{lifecycle_state: "X"}, %{lifecycle_state: "Y"}],
        groups_b: [%{lifecycle_state: "Y"}, %{lifecycle_state: "Z"}]
      }

      assert {:ok, %{groups_a: [%{lifecycle_state: "Y"}], groups_b: [%{lifecycle_state: "Y"}]}} =
               Helpers.apply_filters({:ok, response}, lifecycle_state: ["Y"])
    end
  end
end
