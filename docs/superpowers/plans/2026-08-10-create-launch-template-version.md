# CreateLaunchTemplateVersion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `AwsSdk.EC2` the ability to write a new version of a launch template, so a caller can change which image a template launches.

**Architecture:** One public function following the module's existing shape — positional required inputs with a guard, `opts` last for the optional ones, a `sandbox?/1` branch, a private `do_` function that builds the Query operation and parses the XML reply, a sandbox delegate, and a setter in `AwsSdk.EC2.Sandbox`. The reply is parsed with the `launch_template_data_fields/0` list that `describe_launch_template_versions` already uses, because AWS returns the same `ResponseLaunchTemplateData` structure.

**Tech Stack:** Elixir, SweetXml (`xpath`/`~x`), ExUnit, SandboxRegistry.

**Why this exists:** `deployd` needs each blue/green colour to hold its own image so a deploy has something to roll back to. The full reasoning is in that repository at `docs/superpowers/specs/2026-08-10-a-colour-holds-its-own-release-design.md`. Nothing in this plan depends on reading it — this operation is missing from the SDK on its own terms, since `AwsSdk.EC2` can describe launch templates but not write them.

## Global Constraints

Taken from this repository's `CLAUDE.md`:

- Every input AWS requires is a **positional argument**. `opts` is always last, always `\\ []`, and carries only optional inputs plus credentials, region, endpoint overrides and the sandbox flag.
- Requiredness is enforced by a **guard on the function head** (`when is_binary(launch_template_id)`), never by a runtime check on the keyword list.
- Public functions check `sandbox?(opts)` first and delegate to the `Sandbox` module when true.
- `do_*` functions are an explicit pipeline: `with {:ok, op} <- build_operation(...), {:ok, %{body: body}} <- Client.request(op) do ... end`. No per-module dispatch or response-mapping helpers.
- `AwsSdk.EC2` builds params with `maybe_put/3`, `put_member_list/3` and `put_filters/2`, and parses inline. Match the module you are editing — do not import `flatten_query/1` from the AutoScaling or ELBv2 modules.
- The sandbox registry key is the operation's **first positional argument**, so `set_*_responses` takes `{key_or_regex, fun}` tuples.
- `mix compile` runs with warnings-as-errors outside `:test`.
- Run `mix format` before committing.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/aws_sdk/ec2.ex` | The public function, its `do_` pipeline, the response parser, the sandbox delegate, and the sandbox-unavailable fallback |
| `lib/aws_sdk/ec2/sandbox.ex` | The `create_launch_template_version_response/2` entry and its `set_*_responses/1` setter |
| `test/aws_sdk/ec2/sandbox_test.exs` | Behaviour through the public function with the sandbox enabled |

`AwsSdk.EC2` is a single large module by this repository's design; the new code goes beside `describe_launch_template_versions`, not in a new file.

---

### Task 1: The sandbox entry and its setter

The sandbox comes first because the test in Task 2 drives the public function with the sandbox enabled, and cannot run until the registry knows this operation.

**Files:**
- Modify: `lib/aws_sdk/ec2/sandbox.ex`

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5` and `AwsSdk.Sandbox.register/4`, already used by every other entry in this file.
- Produces:
  - `AwsSdk.EC2.Sandbox.create_launch_template_version_response(launch_template_id, opts)`
  - `AwsSdk.EC2.Sandbox.set_create_launch_template_version_responses(entries)`

- [ ] **Step 1: Read the two neighbouring entries to copy their shape**

Run: `grep -n -A9 "def authorize_security_group_ingress_response" lib/aws_sdk/ec2/sandbox.ex`

Expected: a `_response/2` function that builds a `binding` keyword list and calls `Sandbox.apply/5`, immediately followed by a `set_*_responses/1` that calls `Sandbox.register/4`.

- [ ] **Step 2: Add the entry beside the other launch template entries**

Find `describe_launch_template_versions_response` in `lib/aws_sdk/ec2/sandbox.ex` and add this directly after that function's `set_*_responses` counterpart:

```elixir
    def create_launch_template_version_response(launch_template_id, opts) do
      binding = [launch_template_id: launch_template_id, opts: opts]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :create_launch_template_version,
        launch_template_id,
        binding
      )
    end

    def set_create_launch_template_version_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :create_launch_template_version, entries)
    end
```

- [ ] **Step 3: Compile**

Run: `mix compile`
Expected: no errors. The functions are unused so far, which is not a warning for public functions.

- [ ] **Step 4: Commit**

```bash
git add lib/aws_sdk/ec2/sandbox.ex
git commit -m "feat: sandbox entry for create_launch_template_version"
```

---

### Task 2: The operation

**Files:**
- Modify: `lib/aws_sdk/ec2.ex` — public function and `do_` pipeline beside `describe_launch_template_versions`, the delegate in the sandbox-delegation block, and the fallback in the sandbox-unavailable block
- Test: `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `AwsSdk.EC2.Sandbox.create_launch_template_version_response/2` from Task 1.
- Produces: `AwsSdk.EC2.create_launch_template_version(launch_template_id, launch_template_data, opts \\ [])` returning `{:ok, %{launch_template_version: map(), warning: map() | nil}}` or `{:error, term()}`.

- [ ] **Step 1: Write the failing test**

Add to `test/aws_sdk/ec2/sandbox_test.exs`, inside the module, following the `describe` blocks already there:

```elixir
  describe "create_launch_template_version/3" do
    test "returns the response registered for the launch template id" do
      Sandbox.set_create_launch_template_version_responses([
        {"lt-1",
         fn ->
           {:ok,
            %{
              launch_template_version: %{
                launch_template_id: "lt-1",
                version_number: 2,
                default_version: "false"
              },
              warning: nil
            }}
         end}
      ])

      assert {:ok,
              %{
                launch_template_version: %{
                  launch_template_id: "lt-1",
                  version_number: 2,
                  default_version: "false"
                },
                warning: nil
              }} =
               EC2.create_launch_template_version("lt-1", %{"ImageId" => "ami-1"},
                 sandbox: [enabled: true]
               )
    end

    test "matches the launch template id by regex" do
      Sandbox.set_create_launch_template_version_responses([
        {~r/^lt-/, fn -> {:ok, %{launch_template_version: %{version_number: 7}, warning: nil}} end}
      ])

      assert {:ok, %{launch_template_version: %{version_number: 7}, warning: nil}} =
               EC2.create_launch_template_version("lt-matched", %{"ImageId" => "ami-1"},
                 sandbox: [enabled: true]
               )
    end

    test "passes the launch template id to a function that takes it" do
      Sandbox.set_create_launch_template_version_responses([
        {"lt-1",
         fn launch_template_id ->
           {:ok,
            %{launch_template_version: %{launch_template_id: launch_template_id}, warning: nil}}
         end}
      ])

      assert {:ok, %{launch_template_version: %{launch_template_id: "lt-1"}, warning: nil}} =
               EC2.create_launch_template_version("lt-1", %{"ImageId" => "ami-1"},
                 sandbox: [enabled: true]
               )
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/aws_sdk/ec2/sandbox_test.exs`
Expected: FAIL — `function AwsSdk.EC2.create_launch_template_version/3 is undefined or private`.

- [ ] **Step 3: Add the public function and its pipeline**

In `lib/aws_sdk/ec2.ex`, directly after `do_describe_launch_template_versions/1` and its
`parse_describe_launch_template_versions_for_test/1` and `parse_describe_launch_template_versions/1`
functions, add:

```elixir
  @doc """
  Creates a new version of a launch template.

  `launch_template_data` is AWS's `RequestLaunchTemplateData`, given with AWS's
  own member names, the way `filters` are given elsewhere in this module. Its
  members are sent as `LaunchTemplateData.<Member>`.

  ## Examples

      AwsSdk.EC2.create_launch_template_version("lt-0a1b2c3d", %{"ImageId" => "ami-1"})
      #=> {:ok,
      #=>  %{
      #=>    launch_template_version: %{
      #=>      launch_template_id: "lt-0a1b2c3d",
      #=>      version_number: 2,
      #=>      default_version: "false",
      #=>      launch_template_data: %{image_id: "ami-1"}
      #=>    },
      #=>    warning: nil
      #=>  }}

  A new version is not the default version. An auto scaling group pointed at
  `$Latest` launches it; one pointed at `$Default` does not.

  `:source_version` names the version the new one inherits from — without it,
  a member left out of `launch_template_data` is left out of the new version
  rather than carried over.

  Nested members of `RequestLaunchTemplateData` are not encoded: a value must
  be a scalar AWS accepts as `LaunchTemplateData.<Member>`.
  """
  @spec create_launch_template_version(
          launch_template_id :: String.t(),
          launch_template_data :: map(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def create_launch_template_version(launch_template_id, launch_template_data, opts \\ [])
      when is_binary(launch_template_id) and is_map(launch_template_data) do
    if sandbox?(opts) do
      sandbox_create_launch_template_version_response(launch_template_id, opts)
    else
      do_create_launch_template_version(launch_template_id, launch_template_data, opts)
    end
  end

  defp do_create_launch_template_version(launch_template_id, launch_template_data, opts) do
    params =
      launch_template_data
      |> Enum.reduce(%{"LaunchTemplateId" => launch_template_id}, fn {member, value}, acc ->
        Map.put(acc, "LaunchTemplateData.#{member}", to_string(value))
      end)
      |> maybe_put("SourceVersion", opts[:source_version])
      |> maybe_put("VersionDescription", opts[:version_description])
      |> maybe_put("ClientToken", opts[:client_token])
      |> maybe_put("ResolveAlias", opts[:resolve_alias])

    with {:ok, op} <- build_operation("CreateLaunchTemplateVersion", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_create_launch_template_version(body)}
    end
  end

  @doc false
  def parse_create_launch_template_version_for_test(xml),
    do: parse_create_launch_template_version(xml)

  defp parse_create_launch_template_version(body) do
    %{
      launch_template_version:
        xpath(
          body,
          ~x"//launchTemplateVersion"o,
          launch_template_id: ~x"./launchTemplateId/text()"s,
          launch_template_name: ~x"./launchTemplateName/text()"s,
          version_number: ~x"./versionNumber/text()"oi,
          version_description: ~x"./versionDescription/text()"os,
          create_time: ~x"./createTime/text()"os,
          created_by: ~x"./createdBy/text()"os,
          default_version: ~x"./defaultVersion/text()"os,
          launch_template_data: [~x"./launchTemplateData"o | launch_template_data_fields()]
        ),
      warning:
        xpath(
          body,
          ~x"//warning"o,
          errors: [
            ~x"./errorSet/item"l,
            code: ~x"./code/text()"os,
            message: ~x"./message/text()"os
          ]
        )
    }
  end
```

- [ ] **Step 4: Add the sandbox delegate**

In the sandbox-delegation block of `lib/aws_sdk/ec2.ex` — the run of `defdelegate sandbox_*_response` clauses — add directly after `sandbox_describe_launch_template_versions_response`:

```elixir
    @doc false
    defdelegate sandbox_create_launch_template_version_response(launch_template_id, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :create_launch_template_version_response
```

- [ ] **Step 5: Add the sandbox-unavailable fallback**

In the block of `defp sandbox_*_response(_), do: raise("sandbox not available")` clauses, add
directly after `sandbox_describe_launch_template_versions_response`:

```elixir
    defp sandbox_create_launch_template_version_response(_, _),
      do: raise("sandbox not available")
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `mix test test/aws_sdk/ec2/sandbox_test.exs`
Expected: PASS, including the three new tests.

- [ ] **Step 7: Compile with warnings as errors and format**

Run: `mix compile --warnings-as-errors && mix format --check-formatted`
Expected: no errors. If the formatter reports the file, run `mix format` and re-run.

- [ ] **Step 8: Run the whole suite**

Run: `mix test`
Expected: PASS, 0 failures. Nothing else in the repository calls this function, so the only new tests are the three added.

- [ ] **Step 9: Commit**

```bash
git add lib/aws_sdk/ec2.ex test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 writes a new launch template version"
```

---

### Task 3: Publish a ref deployd can pin

`deployd` depends on this repository by git ref. A change here is invisible to it until a commit exists on the remote and the ref is bumped there.

**Files:**
- None. This task is publishing and reporting.

**Interfaces:**
- Consumes: the commits from Tasks 1 and 2.
- Produces: a commit SHA on `origin/main` for deployd's `mix.exs` to pin.

- [ ] **Step 1: Confirm the working tree is clean and the suite passes**

Run: `git status --short && mix test`
Expected: no output from `git status`, and the suite green.

- [ ] **Step 2: Push**

```bash
git push origin main
```

- [ ] **Step 3: Record the ref**

Run: `git rev-parse HEAD`

Report that SHA. Sub-project 2 pins it in `deployd`'s `mix.exs`, replacing
`c553041a711c54b105a24f183fb7dd0e9fa4e86f`.

Note for whoever does that bump: it carries 24 commits of unrelated work,
including a rewrite of every sandbox module onto `AwsSdk.Sandbox.apply/5`. The
public surface survives that rewrite — the `set_*_responses` setters still
exist and `apply/5` still calls a zero-arity function — but deployd's suite
holds recorded replies behind exactly those two facts, so it has to be run
against the new ref rather than assumed compatible.

---

## Notes for the implementer

- **`launch_template_data` uses AWS's member names, not snake_case.** `%{"ImageId" => "ami-1"}`, not `%{image_id: "ami-1"}`. This matches how `filters` are already passed to this module — `%{"Name" => "tag:ReleaseApp", "Values" => ["cylk_web"]}` — and avoids inventing a mapping between two naming schemes.
- **The reply's parsed keys are snake_case**, because that is what every parser in this module produces. Input takes AWS's names, output gives Elixir's. That asymmetry is the module's existing convention, not a slip.
- **`version_number` is parsed with `oi`** — optional integer — matching `describe_launch_template_versions`. `default_version` is parsed as a string there, and stays a string here for the same reason: AWS sends `true`/`false` as text and this module does not cast it.
- **There is no `create_launch_template_version_by_name`.** AWS accepts a name instead of an id, and this repository's convention is to expose mutually exclusive inputs as separate named functions rather than one polymorphic head. Only the id form is needed, so only it is built; the name form would be a sibling function sending `LaunchTemplateName`, not a second clause of this one.
- **The first real call is what confirms the wire shape.** `LaunchTemplateData.<Member>` is how the Query protocol flattens that structure, and a wrong parameter name fails loudly with an AWS error rather than silently. The recording taken from that first call is what deployd's tests will hold.
