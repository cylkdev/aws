# Endpoint Resolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace this library's hand-rolled endpoint construction with an
evaluator for AWS's published `smithy.rules#endpointRuleSet`, proven against
AWS's published `smithy.rules#endpointTests`.

**Architecture:** AWS ships endpoint resolution as data — a small condition tree
over four parameters, using five functions, resolving to a URL plus SigV4
signing overrides. `AwsSdk.Endpoints.resolve/2` walks that tree at runtime.
Rulesets are extracted from each service's Smithy model into `priv/endpoints/`;
partition data comes from AWS's `partitions.json`.

**Tech Stack:** Elixir, `:json`, `:persistent_term`.

**Runs before:** `docs/superpowers/plans/2026-08-07-codegen-phase-0-2.md`. That
plan originally defined `%AwsSdk.Endpoint{host, region, default_region}` itself —
the hand-rolled approximation this plan replaces. Its Task 2 has been rewritten
to consume what this plan produces, so this must land first or that task has
nothing to stand on.

## Why

`lib/aws_sdk/iam.ex` signs for `us-east-1` and posts to `iam.amazonaws.com`.
IAM's own ruleset resolves **34 distinct hosts** across eight partitions, and the
signing region is `cn-north-1` in China, `us-gov-west-1` in GovCloud and
`us-iso-east-1` in ISO. So the published package sends unsigned-for-that-scope
requests to a hostname that does not resolve, in every partition except
commercial AWS. The same is true of every other global service here, and the
regional services hardcode `.amazonaws.com` in their host templates.

Four things this library hand-rolls that the ruleset already encodes:

| Hand-rolled today | In the ruleset |
|---|---|
| `"iam.amazonaws.com"`, `"autoscaling.{region}.amazonaws.com"` | `{PartitionResult#dnsSuffix}` resolved from the region |
| `@default_region "us-east-1"` pin on global services | `{PartitionResult#implicitGlobalRegion}` plus per-partition `authSchemes` |
| `opts[:iam][:scheme/:host/:port]` overrides | the `Endpoint` parameter — which also *errors* on FIPS-plus-custom-endpoint, where this library silently accepts it |
| nothing | `UseFIPS`, `UseDualStack` |

The `profile:`-carrying-a-region bug documented in `lib/aws_sdk/organizations.ex`
is a symptom of the same root cause: endpoint resolution implemented by hand,
per service.

## Global Constraints

- `mix compile` treats warnings as errors in non-test envs.
- `mix format` must pass.
- No behaviour change for commercial-AWS callers: every existing test must pass
  untouched. The engine is a strictly wider implementation of what exists.
- `priv/endpoints/` ships with the hex package. `models/` does not.
- The ruleset and partition JSON are vendored verbatim and never hand-edited.

## File Structure

| File | Responsibility |
|---|---|
| `lib/aws_sdk/endpoints.ex` | `resolve/2` — walk the rule tree; ruleset loading and caching |
| `lib/aws_sdk/endpoints/partition.ex` | `aws.partition` — region to partition outputs |
| `lib/aws_sdk/endpoints/template.ex` | `{Ref}` and `{Ref#attr}` interpolation |
| `lib/aws_sdk/endpoints/function.ex` | the five ruleset functions |
| `lib/aws_sdk/endpoint.ex` | `%AwsSdk.Endpoint{}` — what remains after host/region leave |
| `lib/mix/tasks/aws_sdk.models.refresh.ex` | download models; extract rulesets and test vectors |
| `models/*.json` | vendored Smithy models, not shipped |
| `priv/endpoints/partitions.json` | vendored from botocore |
| `priv/endpoints/<service>.json` | extracted `smithy.rules#endpointRuleSet` |
| `test/fixtures/endpoints/<service>.json` | extracted `smithy.rules#endpointTests` |
| `test/aws_sdk/endpoints/partition_test.exs` | region to partition |
| `test/aws_sdk/endpoints/template_test.exs` | interpolation |
| `test/aws_sdk/endpoints/function_test.exs` | the five functions |
| `test/aws_sdk/endpoints_conformance_test.exs` | AWS's own vectors, generated per case |

---

### Task 1: Vendor the rulesets, partitions, and test vectors

**Files:**
- Create: `lib/mix/tasks/aws_sdk.models.refresh.ex`
- Create: `models/autoscaling.json`, `models/iam.json`
- Create: `priv/endpoints/partitions.json`
- Create: `priv/endpoints/autoscaling.json`, `priv/endpoints/iam.json`
- Create: `test/fixtures/endpoints/autoscaling.json`, `test/fixtures/endpoints/iam.json`
- Modify: `mix.exs` (`:files` excludes `models`, includes `priv`)

**Interfaces:**
- Consumes: nothing
- Produces: `mix aws_sdk.models.refresh [service]`; the vendored files above

Two services to start — AutoScaling is the simplest regional case and IAM the
hardest global one. The rest are added in Task 7.

- [ ] **Step 1: Fetch by hand and confirm the shapes**

```bash
mkdir -p models priv/endpoints test/fixtures/endpoints
curl -fsSL -o models/autoscaling.json \
  https://raw.githubusercontent.com/aws/aws-sdk-go-v2/main/codegen/sdk-codegen/aws-models/auto-scaling.json
curl -fsSL -o priv/endpoints/partitions.json \
  https://raw.githubusercontent.com/boto/botocore/develop/botocore/data/partitions.json
```

```bash
jq '.partitions | map(.id)' priv/endpoints/partitions.json
jq '.partitions[0] | {outputs, regionRegex, regionCount: (.regions|length)}' priv/endpoints/partitions.json
```

Expected: eight partition ids (`aws`, `aws-cn`, `aws-eusc`, `aws-iso`,
`aws-iso-b`, `aws-iso-e`, `aws-iso-f`, `aws-us-gov`); the `aws` partition's
outputs carrying `dnsSuffix`, `dualStackDnsSuffix`, `implicitGlobalRegion`,
`name`, `supportsDualStack`, `supportsFIPS`; a `regionRegex`; and 35 explicit
regions.

If the structure differs, the file is authoritative — report it rather than
coding around it.

- [ ] **Step 2: Write the refresh task**

```elixir
# lib/mix/tasks/aws_sdk.models.refresh.ex
defmodule Mix.Tasks.AwsSdk.Models.Refresh do
  @shortdoc "Re-pulls AWS service models, endpoint rulesets and test vectors"

  @moduledoc """
  Downloads the Smithy service models, then extracts from each:

    * `smithy.rules#endpointRuleSet` into `priv/endpoints/<service>.json`
    * `smithy.rules#endpointTests` into `test/fixtures/endpoints/<service>.json`

  Also refreshes AWS's partition data into `priv/endpoints/partitions.json`.

      mix aws_sdk.models.refresh          # every service in @services
      mix aws_sdk.models.refresh iam      # one

  Only the extracted rulesets ship with the package; the models themselves are
  large and stay out of it. All of these are committed to git — refreshing them
  can change resolved endpoints, so review the diff and run the conformance
  suite after.
  """

  use Mix.Task

  @models "https://raw.githubusercontent.com/aws/aws-sdk-go-v2/main/codegen/sdk-codegen/aws-models"
  @partitions "https://raw.githubusercontent.com/boto/botocore/develop/botocore/data/partitions.json"

  # local name => upstream model filename
  @services %{
    "autoscaling" => "auto-scaling.json",
    "iam" => "iam.json"
  }

  @ruleset_trait "smithy.rules#endpointRuleSet"
  @tests_trait "smithy.rules#endpointTests"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    services =
      case args do
        [] -> @services
        names -> Map.take(@services, names)
      end

    if services == %{}, do: Mix.raise("no known service in #{inspect(args)}")

    if args == [], do: fetch!(@partitions, "priv/endpoints/partitions.json")

    Enum.each(services, fn {local, remote} ->
      model = "models/#{local}.json"
      fetch!("#{@models}/#{remote}", model)
      extract!(model, local)
    end)
  end

  defp extract!(model_path, local) do
    traits = model_path |> File.read!() |> :json.decode() |> service_traits()

    write_json!("priv/endpoints/#{local}.json", fetch_trait!(traits, @ruleset_trait, local))
    write_json!("test/fixtures/endpoints/#{local}.json", fetch_trait!(traits, @tests_trait, local))
  end

  defp service_traits(%{"shapes" => shapes}) do
    shapes
    |> Enum.find_value(fn {_id, shape} ->
      if shape["type"] == "service", do: shape["traits"]
    end)
    |> case do
      nil -> Mix.raise("no service shape in model")
      traits -> traits
    end
  end

  defp fetch_trait!(traits, trait, local) do
    case Map.fetch(traits, trait) do
      {:ok, value} -> value
      :error -> Mix.raise("#{local} has no #{trait}")
    end
  end

  defp write_json!(path, term) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, term |> :json.encode() |> IO.iodata_to_binary())
    Mix.shell().info("wrote #{path}")
  end

  defp fetch!(url, path) do
    File.mkdir_p!(Path.dirname(path))
    Mix.shell().info("fetching #{url} -> #{path}")

    case System.cmd("curl", ["-fsSL", "-o", path, url]) do
      {_out, 0} -> :ok
      {out, code} -> Mix.raise("curl failed (#{code}) for #{url}: #{out}")
    end
  end
end
```

- [ ] **Step 3: Run it and check what landed**

Run: `mix aws_sdk.models.refresh`
Expected: six files written

```bash
jq 'length' test/fixtures/endpoints/autoscaling.json  # the testCases wrapper
jq '.testCases | length' test/fixtures/endpoints/autoscaling.json
jq '.testCases | length' test/fixtures/endpoints/iam.json
jq -r '[.. | objects | .fn? // empty] | unique | .[]' priv/endpoints/iam.json
```

Expected: 45 and 26 test cases; the function list is exactly `aws.partition`,
`booleanEquals`, `getAttr`, `isSet`, `stringEquals`.

**If any other function appears, stop.** Tasks 4 and 5 implement exactly those
five. A sixth means the vocabulary is wider than this plan assumes, and that is a
finding to report before writing the evaluator, not something to patch in.

- [ ] **Step 4: Keep models out of the package**

In `mix.exs`, the `package/0` `:files` list must include `priv` and exclude
`models`:

```elixir
      files: ~w(lib priv mix.exs README.md LICENSE CHANGELOG.md)
```

Run: `mix hex.build --unpack -o /tmp/pkg && ls /tmp/pkg && ls /tmp/pkg/priv/endpoints`
Expected: no `models` directory; `partitions.json`, `autoscaling.json`, `iam.json` present

- [ ] **Step 5: Commit**

```bash
git add mix.exs models priv/endpoints test/fixtures/endpoints lib/mix/tasks/aws_sdk.models.refresh.ex
git commit -m "chore: vendor AWS endpoint rulesets, partitions and test vectors"
```

---

### Task 2: `AwsSdk.Endpoints.Partition`

Implements the `aws.partition` function: a region string in, that partition's
outputs out.

**Files:**
- Create: `lib/aws_sdk/endpoints/partition.ex`
- Test: `test/aws_sdk/endpoints/partition_test.exs`

**Interfaces:**
- Consumes: `priv/endpoints/partitions.json` (Task 1)
- Produces: `AwsSdk.Endpoints.Partition.resolve(region :: binary) :: map | nil`

- [ ] **Step 1: Write the failing test**

```elixir
# test/aws_sdk/endpoints/partition_test.exs
defmodule AwsSdk.Endpoints.PartitionTest do
  use ExUnit.Case, async: true

  alias AwsSdk.Endpoints.Partition

  test "an explicitly listed region resolves to its partition" do
    assert %{"name" => "aws", "dnsSuffix" => "amazonaws.com"} = Partition.resolve("us-east-1")
  end

  test "a China region resolves to aws-cn" do
    outputs = Partition.resolve("cn-north-1")

    assert outputs["name"] == "aws-cn"
    assert outputs["dnsSuffix"] == "amazonaws.com.cn"
    assert outputs["implicitGlobalRegion"] == "cn-northwest-1"
  end

  test "a GovCloud region resolves to aws-us-gov" do
    assert Partition.resolve("us-gov-west-1")["name"] == "aws-us-gov"
  end

  test "an unlisted region matching a partition's regionRegex still resolves" do
    # not in the aws partition's explicit region list, but matches its regex
    outputs = Partition.resolve("us-east-9")

    assert outputs["name"] == "aws"
    assert outputs["dnsSuffix"] == "amazonaws.com"
  end

  test "an unrecognised region falls back to the aws partition" do
    assert Partition.resolve("not-a-region")["name"] == "aws"
  end

  test "every partition exposes the outputs the rulesets reference" do
    for region <- ~w(us-east-1 cn-north-1 us-gov-west-1 us-iso-east-1) do
      outputs = Partition.resolve(region)

      assert is_binary(outputs["dnsSuffix"])
      assert is_binary(outputs["dualStackDnsSuffix"])
      assert is_binary(outputs["implicitGlobalRegion"])
      assert is_boolean(outputs["supportsFIPS"])
      assert is_boolean(outputs["supportsDualStack"])
    end
  end
end
```

The fallback in the fifth test is not an invention — it is what the partitions
format specifies, and what every AWS SDK does: an unmatched region resolves to
the default partition so a newly launched region works before the data file
catches up.

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/aws_sdk/endpoints/partition_test.exs`
Expected: FAIL — `AwsSdk.Endpoints.Partition.resolve/1 is undefined`

- [ ] **Step 3: Implement it**

```elixir
# lib/aws_sdk/endpoints/partition.ex
defmodule AwsSdk.Endpoints.Partition do
  @moduledoc """
  Resolves an AWS region to its partition's outputs.

  This is the `aws.partition` function that `smithy.rules#endpointRuleSet`
  documents call. The data is AWS's own `partitions.json`, vendored at
  `priv/endpoints/partitions.json`.

  Matching is in the order the format specifies:

    1. the region appears in a partition's explicit `regions` map
    2. the region matches a partition's `regionRegex`
    3. otherwise the default partition, `aws`

  Step 3 matters: a region launched after this data file was vendored still
  resolves, rather than failing. It may resolve to the wrong partition for a new
  non-commercial region, which is why `mix aws_sdk.models.refresh` exists.

      iex> AwsSdk.Endpoints.Partition.resolve("cn-north-1")["dnsSuffix"]
      "amazonaws.com.cn"
  """

  @default "aws"
  @key {__MODULE__, :partitions}

  @doc """
  Returns the partition outputs for `region`.

  The map's keys are AWS's, unchanged — `"dnsSuffix"`, `"dualStackDnsSuffix"`,
  `"implicitGlobalRegion"`, `"name"`, `"supportsFIPS"`, `"supportsDualStack"` —
  because ruleset templates reference them by those exact names.
  """
  @spec resolve(String.t()) :: map
  def resolve(region) when is_binary(region) do
    partitions = partitions()

    explicit(partitions, region) || by_regex(partitions, region) || default(partitions)
  end

  defp explicit(partitions, region) do
    Enum.find_value(partitions, fn partition ->
      if Map.has_key?(partition["regions"], region), do: partition["outputs"]
    end)
  end

  defp by_regex(partitions, region) do
    Enum.find_value(partitions, fn partition ->
      if Regex.match?(Regex.compile!(partition["regionRegex"]), region),
        do: partition["outputs"]
    end)
  end

  defp default(partitions) do
    Enum.find_value(partitions, fn partition ->
      if partition["id"] == @default, do: partition["outputs"]
    end)
  end

  defp partitions do
    case :persistent_term.get(@key, nil) do
      nil ->
        loaded = load()
        :persistent_term.put(@key, loaded)
        loaded

      loaded ->
        loaded
    end
  end

  defp load do
    :aws_sdk
    |> Application.app_dir("priv/endpoints/partitions.json")
    |> File.read!()
    |> :json.decode()
    |> Map.fetch!("partitions")
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mix test test/aws_sdk/endpoints/partition_test.exs`
Expected: PASS, 6 tests

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/endpoints/partition.ex test/aws_sdk/endpoints/partition_test.exs
git commit -m "feat: resolve AWS regions to partition outputs"
```

---

### Task 3: `AwsSdk.Endpoints.Template`

Ruleset URLs are templates: `"https://iam.{PartitionResult#implicitGlobalRegion}.{PartitionResult#dnsSuffix}"`.

**Files:**
- Create: `lib/aws_sdk/endpoints/template.ex`
- Test: `test/aws_sdk/endpoints/template_test.exs`

**Interfaces:**
- Consumes: nothing
- Produces: `AwsSdk.Endpoints.Template.expand(template :: binary, scope :: map) :: binary`

- [ ] **Step 1: Write the failing test**

```elixir
# test/aws_sdk/endpoints/template_test.exs
defmodule AwsSdk.Endpoints.TemplateTest do
  use ExUnit.Case, async: true

  alias AwsSdk.Endpoints.Template

  @scope %{
    "Region" => "eu-west-2",
    "PartitionResult" => %{"dnsSuffix" => "amazonaws.com", "implicitGlobalRegion" => "us-east-1"}
  }

  test "expands a plain reference" do
    assert Template.expand("https://autoscaling.{Region}.amazonaws.com", @scope) ==
             "https://autoscaling.eu-west-2.amazonaws.com"
  end

  test "expands an attribute reference" do
    assert Template.expand("https://a.{Region}.{PartitionResult#dnsSuffix}", @scope) ==
             "https://a.eu-west-2.amazonaws.com"
  end

  test "expands several references in one template" do
    assert Template.expand(
             "https://iam.{PartitionResult#implicitGlobalRegion}.{PartitionResult#dnsSuffix}",
             @scope
           ) == "https://iam.us-east-1.amazonaws.com"
  end

  test "a template with no references is returned unchanged" do
    assert Template.expand("https://iam.amazonaws.com", @scope) == "https://iam.amazonaws.com"
  end

  test "an unresolvable reference raises rather than emitting a broken URL" do
    assert_raise KeyError, fn -> Template.expand("https://{Nope}", @scope) end
  end
end
```

That last test is the important one. A missing reference must not silently
produce `https://` or a literal `{Nope}` — either would be a request to a
plausible-looking wrong host.

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/aws_sdk/endpoints/template_test.exs`
Expected: FAIL — `AwsSdk.Endpoints.Template.expand/2 is undefined`

- [ ] **Step 3: Implement it**

```elixir
# lib/aws_sdk/endpoints/template.ex
defmodule AwsSdk.Endpoints.Template do
  @moduledoc """
  Expands the `{Ref}` and `{Ref#attr}` placeholders in a ruleset URL template.

      iex> scope = %{"Region" => "eu-west-2", "P" => %{"dnsSuffix" => "amazonaws.com"}}
      iex> AwsSdk.Endpoints.Template.expand("https://s.{Region}.{P#dnsSuffix}", scope)
      "https://s.eu-west-2.amazonaws.com"

  An unresolvable reference raises. Emitting a URL with an unexpanded
  placeholder, or with the segment silently dropped, would mean signing and
  sending a request to a host nobody chose.
  """

  @pattern ~r/\{([A-Za-z0-9_]+)(?:#([A-Za-z0-9_]+))?\}/

  @spec expand(String.t(), map) :: String.t()
  def expand(template, scope) when is_binary(template) and is_map(scope) do
    Regex.replace(@pattern, template, fn _match, ref, attr ->
      scope
      |> Map.fetch!(ref)
      |> resolve_attr(attr, ref)
      |> to_string()
    end)
  end

  defp resolve_attr(value, "", _ref), do: value
  defp resolve_attr(value, attr, ref) when is_map(value), do: Map.fetch!(value, attr)

  defp resolve_attr(_value, attr, ref) do
    raise KeyError, key: attr, term: ref
  end
end
```

`Regex.replace/3` passes `""` rather than `nil` for a group that did not
participate, which is why the first `resolve_attr/3` clause matches on `""`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `mix test test/aws_sdk/endpoints/template_test.exs`
Expected: PASS, 5 tests

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/endpoints/template.ex test/aws_sdk/endpoints/template_test.exs
git commit -m "feat: expand ruleset URL templates"
```

---

### Task 4: `AwsSdk.Endpoints.Function`

The five functions the rulesets use. Task 1 Step 3 proved there are exactly five.

**Files:**
- Create: `lib/aws_sdk/endpoints/function.ex`
- Test: `test/aws_sdk/endpoints/function_test.exs`

**Interfaces:**
- Consumes: `AwsSdk.Endpoints.Partition` (Task 2)
- Produces: `AwsSdk.Endpoints.Function.call(fn_name :: binary, argv :: list, scope :: map) :: term`

- [ ] **Step 1: Write the failing test**

```elixir
# test/aws_sdk/endpoints/function_test.exs
defmodule AwsSdk.Endpoints.FunctionTest do
  use ExUnit.Case, async: true

  alias AwsSdk.Endpoints.Function

  @scope %{"Region" => "us-east-1", "UseFIPS" => false}

  describe "isSet" do
    test "true for a bound parameter" do
      assert Function.call("isSet", [%{"ref" => "Region"}], @scope) == true
    end

    test "false for an unbound parameter" do
      assert Function.call("isSet", [%{"ref" => "Endpoint"}], @scope) == false
    end

    test "false for a parameter explicitly bound to nil" do
      assert Function.call("isSet", [%{"ref" => "Endpoint"}], %{"Endpoint" => nil}) == false
    end
  end

  describe "booleanEquals" do
    test "compares a ref against a literal" do
      assert Function.call("booleanEquals", [%{"ref" => "UseFIPS"}, false], @scope) == true
      assert Function.call("booleanEquals", [%{"ref" => "UseFIPS"}, true], @scope) == false
    end
  end

  describe "stringEquals" do
    test "compares a ref against a literal" do
      assert Function.call("stringEquals", [%{"ref" => "Region"}, "us-east-1"], @scope) == true
      assert Function.call("stringEquals", [%{"ref" => "Region"}, "eu-west-2"], @scope) == false
    end
  end

  describe "aws.partition" do
    test "returns the partition outputs for a region ref" do
      result = Function.call("aws.partition", [%{"ref" => "Region"}], @scope)

      assert result["name"] == "aws"
      assert result["dnsSuffix"] == "amazonaws.com"
    end
  end

  describe "getAttr" do
    test "reads a named attribute off a ref'd map" do
      scope = Map.put(@scope, "P", %{"dnsSuffix" => "amazonaws.com"})

      assert Function.call("getAttr", [%{"ref" => "P"}, "dnsSuffix"], scope) == "amazonaws.com"
    end
  end

  test "an unknown function raises rather than resolving to a wrong endpoint" do
    assert_raise RuntimeError, ~r/unsupported endpoint function "aws.isVirtualHostableS3Bucket"/, fn ->
      Function.call("aws.isVirtualHostableS3Bucket", [], @scope)
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/aws_sdk/endpoints/function_test.exs`
Expected: FAIL — `AwsSdk.Endpoints.Function.call/3 is undefined`

- [ ] **Step 3: Implement it**

```elixir
# lib/aws_sdk/endpoints/function.ex
defmodule AwsSdk.Endpoints.Function do
  @moduledoc """
  The functions that `smithy.rules#endpointRuleSet` conditions call.

  Five of them cover every service model this library vendors, verified by
  `mix aws_sdk.models.refresh`'s extraction check. S3's ruleset uses more
  (`parseURL`, `substring`, `uriEncode`, `aws.isVirtualHostableS3Bucket`); adding
  S3 means adding those here first.

  An unknown function raises. Treating it as false would silently take the wrong
  branch of the tree and resolve to a plausible but wrong endpoint.
  """

  alias AwsSdk.Endpoints.Partition

  @spec call(String.t(), list, map) :: term
  def call("isSet", [arg], scope), do: argument(arg, scope) != nil

  def call("booleanEquals", [left, right], scope),
    do: argument(left, scope) === argument(right, scope)

  def call("stringEquals", [left, right], scope),
    do: argument(left, scope) === argument(right, scope)

  def call("getAttr", [arg, path], scope), do: get_attr(argument(arg, scope), path)

  def call("aws.partition", [arg], scope) do
    case argument(arg, scope) do
      region when is_binary(region) -> Partition.resolve(region)
      _other -> nil
    end
  end

  def call(name, _argv, _scope) do
    raise "unsupported endpoint function #{inspect(name)}"
  end

  @doc """
  Resolves a ruleset argument: a `{"ref" => name}` lookup, a nested `{"fn" => ...}`
  call, or a literal.
  """
  @spec argument(term, map) :: term
  def argument(%{"ref" => name}, scope), do: Map.get(scope, name)
  def argument(%{"fn" => name, "argv" => argv}, scope), do: call(name, argv, scope)
  def argument(literal, _scope), do: literal

  # getAttr paths are dotted and may index a list: "supportsFIPS", "a.b", "a[0]".
  defp get_attr(nil, _path), do: nil

  defp get_attr(value, path) do
    path
    |> String.split(".")
    |> Enum.reduce(value, &step/2)
  end

  defp step(segment, acc) do
    case Regex.run(~r/^([A-Za-z0-9_]*)\[(\d+)\]$/, segment) do
      [_all, "", index] -> Enum.at(acc, String.to_integer(index))
      [_all, key, index] -> acc |> Map.get(key) |> Enum.at(String.to_integer(index))
      nil -> Map.get(acc, segment)
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mix test test/aws_sdk/endpoints/function_test.exs`
Expected: PASS, 10 tests

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/endpoints/function.ex test/aws_sdk/endpoints/function_test.exs
git commit -m "feat: implement the five endpoint ruleset functions"
```

---

### Task 5: `AwsSdk.Endpoints.resolve/2`

The tree walker. A ruleset is a list of rules; each has `conditions`, and is one
of `type: "tree"` (recurse into `rules`), `"endpoint"` (resolve and return), or
`"error"` (raise the message). Conditions that bind a result via `assign` extend
the scope for everything below.

**Files:**
- Create: `lib/aws_sdk/endpoints.ex`
- Test: covered by Task 6's conformance suite

**Interfaces:**
- Consumes: `AwsSdk.Endpoints.Function` (Task 4), `AwsSdk.Endpoints.Template` (Task 3)
- Produces:
  - `AwsSdk.Endpoints.resolve(service :: binary, params :: map) :: {:ok, resolved} | {:error, binary}`
  - `resolved :: %{url: binary, signing_region: binary | nil, signing_name: binary | nil}`
  - `AwsSdk.Endpoints.ruleset(service :: binary) :: map`

- [ ] **Step 1: Confirm the `assign` key exists before coding for it**

```bash
jq -r '[.. | objects | select(has("assign")) | .assign] | unique | .[]' priv/endpoints/iam.json
```

Expected: `PartitionResult`. If nothing is returned, `assign` is unused and the
scope never grows — simplify accordingly and note it. If other names appear, they
are additional bindings and the implementation below already handles them.

- [ ] **Step 2: Write the implementation**

There is no unit test for this task — Task 6 runs AWS's own 71 vectors against
it, which is a far stronger check than anything hand-written here. Write the
module, then go straight to Task 6.

```elixir
# lib/aws_sdk/endpoints.ex
defmodule AwsSdk.Endpoints do
  @moduledoc """
  Resolves an AWS endpoint by evaluating the service's published rule set.

  AWS ships endpoint resolution as data — `smithy.rules#endpointRuleSet` on each
  service's Smithy model — because it is not a host template. It varies by
  partition, by FIPS and dual-stack selection, and by whether the caller supplied
  an endpoint of their own, and it carries SigV4 signing overrides that differ
  per partition. IAM alone resolves to 34 hosts, signing in `us-east-1`,
  `cn-north-1`, `us-gov-west-1` or `us-iso-east-1` depending on the region.

  The rule sets are vendored under `priv/endpoints/` by
  `mix aws_sdk.models.refresh`. Evaluation happens at call time, not at build
  time, because the region arrives with the call and because baking one
  partition into the package would make it unusable in the others.

  ## Parameters

    * `"Region"` — required by every service model here
    * `"UseFIPS"` — defaults to `false`
    * `"UseDualStack"` — defaults to `false`
    * `"Endpoint"` — a caller-supplied endpoint, which the rule set validates;
      combining it with FIPS or dual-stack is an error AWS defines, not one this
      module invents

  ## Examples

      AwsSdk.Endpoints.resolve("autoscaling", %{"Region" => "eu-west-2"})
      #=> {:ok, %{url: "https://autoscaling.eu-west-2.amazonaws.com",
      #=>         signing_region: nil, signing_name: nil}}

      AwsSdk.Endpoints.resolve("iam", %{"Region" => "cn-north-1"})
      #=> {:ok, %{url: "https://iam.cn-north-1.amazonaws.com.cn",
      #=>         signing_region: "cn-north-1", signing_name: "iam"}}
  """

  alias AwsSdk.Endpoints.{Function, Template}

  @defaults %{"UseFIPS" => false, "UseDualStack" => false}

  @type resolved :: %{
          url: String.t(),
          signing_region: String.t() | nil,
          signing_name: String.t() | nil
        }

  @doc """
  Resolves `service`'s endpoint for `params`.

  Returns `{:error, message}` with AWS's own wording when the rule set rejects
  the parameters, and when no rule matches.
  """
  @spec resolve(String.t(), map) :: {:ok, resolved} | {:error, String.t()}
  def resolve(service, params) when is_binary(service) and is_map(params) do
    ruleset = ruleset(service)
    scope = @defaults |> Map.merge(defaults(ruleset)) |> Map.merge(params)

    case walk(ruleset["rules"], scope) do
      {:ok, endpoint, final_scope} -> {:ok, build(endpoint, final_scope)}
      {:error, message} -> {:error, message}
      :nomatch -> {:error, "no endpoint rule matched for #{service}"}
    end
  end

  @doc "Returns the vendored rule set for `service`, cached after first read."
  @spec ruleset(String.t()) :: map
  def ruleset(service) do
    key = {__MODULE__, service}

    case :persistent_term.get(key, nil) do
      nil ->
        loaded = load(service)
        :persistent_term.put(key, loaded)
        loaded

      loaded ->
        loaded
    end
  end

  defp load(service) do
    :aws_sdk
    |> Application.app_dir("priv/endpoints/#{service}.json")
    |> File.read!()
    |> :json.decode()
  end

  # Parameter defaults declared by the rule set itself.
  defp defaults(ruleset) do
    ruleset
    |> Map.get("parameters", %{})
    |> Enum.reduce(%{}, fn {name, spec}, acc ->
      case Map.fetch(spec, "default") do
        {:ok, value} -> Map.put(acc, name, value)
        :error -> acc
      end
    end)
  end

  defp walk([], _scope), do: :nomatch

  defp walk([rule | rest], scope) do
    case evaluate(rule["conditions"] || [], scope) do
      :no ->
        walk(rest, scope)

      {:yes, scope} ->
        case rule["type"] do
          "endpoint" -> {:ok, rule["endpoint"], scope}
          "error" -> {:error, Template.expand(rule["error"], scope)}
          "tree" -> descend(rule, rest, scope)
        end
    end
  end

  # A tree whose own conditions passed but whose children all failed falls
  # through to the next sibling, which is what the spec requires.
  defp descend(rule, rest, scope) do
    case walk(rule["rules"], scope) do
      :nomatch -> walk(rest, scope)
      result -> result
    end
  end

  defp evaluate([], scope), do: {:yes, scope}

  defp evaluate([condition | rest], scope) do
    value = Function.call(condition["fn"], condition["argv"], scope)

    if truthy?(value) do
      evaluate(rest, assign(condition, value, scope))
    else
      :no
    end
  end

  defp assign(%{"assign" => name}, value, scope), do: Map.put(scope, name, value)
  defp assign(_condition, _value, scope), do: scope

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(_other), do: true

  defp build(endpoint, scope) do
    auth = endpoint |> Map.get("properties", %{}) |> Map.get("authSchemes", []) |> List.first()

    %{
      url: endpoint["url"] |> Function.argument(scope) |> expand(scope),
      signing_region: auth && expand_maybe(auth["signingRegion"], scope),
      signing_name: auth && expand_maybe(auth["signingName"], scope)
    }
  end

  defp expand(url, scope) when is_binary(url), do: Template.expand(url, scope)

  defp expand_maybe(nil, _scope), do: nil
  defp expand_maybe(value, scope), do: Template.expand(value, scope)
end
```

Two details worth understanding rather than copying blindly:

- `endpoint["url"]` is sometimes a template string and sometimes `{"ref" => "Endpoint"}`
  — the custom-endpoint branch returns the caller's URL by reference. Running it
  through `Function.argument/2` first handles both.
- A `"tree"` whose conditions pass but whose children all fail must fall through
  to the *next sibling*, not abort. Getting this wrong makes some regions resolve
  to an error instead of an endpoint, and AWS's vectors in Task 6 catch it.

- [ ] **Step 3: Smoke-check by hand before the full suite**

```bash
mix run -e '
  IO.inspect AwsSdk.Endpoints.resolve("autoscaling", %{"Region" => "eu-west-2"})
  IO.inspect AwsSdk.Endpoints.resolve("iam", %{"Region" => "us-east-1"})
  IO.inspect AwsSdk.Endpoints.resolve("iam", %{"Region" => "cn-north-1"})
  IO.inspect AwsSdk.Endpoints.resolve("iam", %{"Region" => "us-gov-west-1"})
'
```

Expected: `https://autoscaling.eu-west-2.amazonaws.com`;
`https://iam.amazonaws.com`; `https://iam.cn-north-1.amazonaws.com.cn` signing in
`cn-north-1`; `https://iam.us-gov.amazonaws.com` signing in `us-gov-west-1`.

The last two are what the current library gets wrong.

- [ ] **Step 4: Commit**

```bash
git add lib/aws_sdk/endpoints.ex
git commit -m "feat: evaluate AWS endpoint rule sets at call time"
```

---

### Task 6: Conformance against AWS's own vectors

**Files:**
- Create: `test/aws_sdk/endpoints_conformance_test.exs`

**Interfaces:**
- Consumes: `AwsSdk.Endpoints.resolve/2` (Task 5), `test/fixtures/endpoints/*.json` (Task 1)
- Produces: one ExUnit test per published case — 71 to start

- [ ] **Step 1: Write the suite**

```elixir
# test/aws_sdk/endpoints_conformance_test.exs
defmodule AwsSdk.EndpointsConformanceTest do
  @moduledoc """
  AWS's own endpoint test vectors, run against `AwsSdk.Endpoints.resolve/2`.

  These are `smithy.rules#endpointTests` extracted verbatim from each service
  model by `mix aws_sdk.models.refresh`. They are the authority on what an
  endpoint should resolve to: every case here was written by AWS to test their
  own SDKs, and covers partitions, FIPS, dual-stack, custom endpoints and the
  configurations that are supposed to fail.

  Tests are generated at compile time, one per case, so a failure names the
  service and AWS's own description of the scenario.
  """

  use ExUnit.Case, async: true

  services =
    "test/fixtures/endpoints/*.json"
    |> Path.wildcard()
    |> Enum.map(fn path ->
      {Path.basename(path, ".json"), path |> File.read!() |> :json.decode()}
    end)

  for {service, %{"testCases" => cases}} <- services,
      {test_case, index} <- Enum.with_index(cases) do
    @service service
    @params Map.get(test_case, "params", %{})
    @expect Map.fetch!(test_case, "expect")
    @description Map.get(test_case, "documentation", "case #{index}")

    test "#{service}: #{@description}" do
      result = AwsSdk.Endpoints.resolve(@service, @params)

      case @expect do
        %{"endpoint" => expected} ->
          assert {:ok, resolved} = result
          assert resolved.url == expected["url"]
          assert_auth(resolved, expected)

        %{"error" => message} ->
          assert {:error, ^message} = result
      end
    end
  end

  defp assert_auth(resolved, expected) do
    case get_in(expected, ["properties", "authSchemes"]) do
      [%{} = scheme | _rest] ->
        if region = scheme["signingRegion"], do: assert(resolved.signing_region == region)
        if name = scheme["signingName"], do: assert(resolved.signing_name == name)

      _absent ->
        :ok
    end
  end
end
```

Generating one test per case rather than looping inside one test is deliberate:
71 assertions in a single test stop at the first failure and tell you nothing
about the other 70.

- [ ] **Step 2: Run it**

Run: `mix test test/aws_sdk/endpoints_conformance_test.exs`
Expected: PASS, 71 tests (45 AutoScaling, 26 IAM)

Every failure here is a real defect in Tasks 2–5, not a test to adjust. AWS's
vectors are the specification. The likely culprits, in order:

1. tree fall-through (Task 5 Step 2, second note) — shows up as several regions
   returning `{:error, ...}` where an endpoint was expected
2. `getAttr` path parsing — shows up on `supportsFIPS`/`supportsDualStack` cases
3. partition regex ordering — shows up as a GovCloud or ISO region resolving into
   the `aws` partition

- [ ] **Step 3: Commit**

```bash
git add test/aws_sdk/endpoints_conformance_test.exs
git commit -m "test: run AWS's published endpoint vectors against the resolver"
```

---

### Task 7: Wire it in, and delete the hand-rolled resolution

**Files:**
- Create: `lib/aws_sdk/endpoint.ex`
- Modify: `lib/aws_sdk/client.ex`
- Modify: all nine service modules
- Modify: `lib/mix/tasks/aws_sdk.models.refresh.ex` (`@services`)
- Test: existing suite, unchanged

**Interfaces:**
- Consumes: `AwsSdk.Endpoints.resolve/2` (Task 5)
- Produces: `%AwsSdk.Endpoint{signing_name, api_version, content_type, target_prefix, service_id, override_key}`

- [ ] **Step 1: Vendor the remaining seven services**

Add to `@services` in the refresh task, then run it:

```elixir
  @services %{
    "autoscaling" => "auto-scaling.json",
    "iam" => "iam.json",
    "sts" => "sts.json",
    "ec2" => "ec2.json",
    "elasticloadbalancingv2" => "elastic-load-balancing-v2.json",
    "events" => "eventbridge.json",
    "logs" => "cloudwatch-logs.json",
    "organizations" => "organizations.json",
    "ssm" => "ssm.json",
    "sso-admin" => "sso-admin.json",
    "identitystore" => "identitystore.json"
  }
```

Run: `mix aws_sdk.models.refresh && mix test test/aws_sdk/endpoints_conformance_test.exs`

The upstream filenames above are the expected ones; if a fetch 404s, list the
directory and use the real name rather than guessing again:

```bash
curl -fsSL https://api.github.com/repos/aws/aws-sdk-go-v2/contents/codegen/sdk-codegen/aws-models \
  | jq -r '.[].name' | grep -iE 'iam|sts|ec2|elastic|event|logs|organizations|ssm|sso|identity'
```

Expected: the conformance suite grows to several hundred cases and stays green.
Any new failure is a service exercising a rule shape AutoScaling and IAM did not
— fix Tasks 2–5, do not skip the case.

- [ ] **Step 2: Define what remains of `%AwsSdk.Endpoint{}`**

```elixir
# lib/aws_sdk/endpoint.ex
defmodule AwsSdk.Endpoint do
  @moduledoc """
  Per-service wire framing: how a request is shaped, not where it goes.

  Where it goes is `AwsSdk.Endpoints.resolve/2`, driven by AWS's published rule
  set. This struct holds only what the rule set does not: the SigV4 service name,
  the API version, the content type, the JSON 1.1 target prefix, and the opts key
  a caller uses to override the endpoint.

  `:service_id` names the vendored rule set under `priv/endpoints/`.

      %AwsSdk.Endpoint{
        signing_name: "autoscaling",
        api_version: "2011-01-01",
        content_type: "application/x-www-form-urlencoded",
        service_id: "autoscaling",
        override_key: :auto_scaling
      }
  """

  @enforce_keys [:signing_name, :api_version, :content_type, :service_id, :override_key]
  defstruct [:signing_name, :api_version, :content_type, :target_prefix, :service_id, :override_key]

  @type t :: %__MODULE__{
          signing_name: String.t(),
          api_version: String.t(),
          content_type: String.t(),
          target_prefix: String.t() | nil,
          service_id: String.t(),
          override_key: atom
        }
end
```

`:host`, `:region` and `:default_region` are gone. So is the global-versus-regional
distinction — the rule set carries it.

- [ ] **Step 3: Route `AwsSdk.Client` through the resolver**

Read `lib/aws_sdk/client.ex`'s `resolve_config/3` and `simple_url/1` first. Replace
the host-function argument with a call to `AwsSdk.Endpoints.resolve/2`, mapping
per-call opts onto rule set parameters:

| opts | parameter |
|---|---|
| `:region` (or the resolved config region) | `"Region"` |
| `opts[override_key][:url]`, or `:scheme`/`:host`/`:port` composed | `"Endpoint"` |
| `:use_fips` | `"UseFIPS"` |
| `:use_dual_stack` | `"UseDualStack"` |

The resolver's `signing_region` and `signing_name`, when present, win over the
configured region and the endpoint's `signing_name` for the `%AwsSdk.Operation{}`
— that is the whole point of the `authSchemes` property, and it is what makes IAM
sign correctly in China and GovCloud.

Keep `:scheme`/`:host`/`:port` working: compose them into an `"Endpoint"` URL
rather than dropping them. Existing tests and any LocalStack setup depend on
them, and the rule set validates a custom endpoint properly.

- [ ] **Step 4: Migrate the nine services**

Per service: replace `@service`/`@content_type`/`@api_version`/`@default_region`
and the host function with one `@endpoint %AwsSdk.Endpoint{}`, and delete the
host function. `AwsSdk.Organizations` additionally loses its
`Keyword.put(opts, :region, global_region(opts[:region]))` line and
`global_region/1` — the rule set decides that now. `AwsSdk.IAM` and `AwsSdk.STS`
lose their pinned `us-east-1` defaults for the same reason.

One service at a time, running its tests in between.

- [ ] **Step 5: Verify no hand-rolled host construction survives**

```bash
grep -rn "amazonaws\.com" lib/ --include=*.ex
```

Expected: no output. Every hostname now comes from `priv/endpoints/`.

- [ ] **Step 6: Run the full suite**

Run: `mix format && mix compile --warnings-as-errors && mix test`
Expected: PASS. No existing test should need changing — commercial-AWS behaviour
is unchanged, and that is the check that this widened the implementation rather
than altering it.

- [ ] **Step 7: Changelog and commit**

```markdown
### Added

- FIPS and dual-stack endpoints, via `use_fips: true` / `use_dual_stack: true`.
- Support for the China, GovCloud and ISO partitions.

### Fixed

- Global services (IAM, STS, Organizations) resolved to commercial-AWS hosts and
  signed for `us-east-1` in every partition. They now resolve and sign per
  partition — `iam.cn-north-1.amazonaws.com.cn` signing in `cn-north-1`,
  `iam.us-gov.amazonaws.com` signing in `us-gov-west-1`.
- A `profile:` carrying a region no longer produces an unresolvable host for
  global services.
```

```bash
git add lib test CHANGELOG.md models priv
git commit -m "feat: resolve endpoints from AWS's published rule sets

Replaces per-service hand-rolled host construction. Adds partition, FIPS and
dual-stack support, and fixes global-service signing outside commercial AWS.
Verified against AWS's own published endpoint test vectors."
```

## Done when

- `grep -rn "amazonaws\.com" lib/ --include=*.ex` returns nothing.
- The conformance suite runs every published case for all eleven vendored rule
  sets, and passes.
- No service module defines a host function, a `@default_region`, or a
  global-region special case.
- The existing suite passes untouched.

## Not in this plan

- S3. Its rule set uses `parseURL`, `substring`, `uriEncode` and
  `aws.isVirtualHostableS3Bucket`, which Task 4 does not implement, and its
  virtual-hosted addressing interacts with bucket names. S3 keeps its current
  URL composition until the codegen plan's Phase 4, which is where the rest of
  S3's request construction is handled; adding the four functions there makes
  `AwsSdk.Endpoints` cover it.
- Endpoint resolution for the credential providers (`AwsSdk.Credentials.*`),
  which reach IMDS, ECS and SSO endpoints that are not service rule sets.
