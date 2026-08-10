# ModifyLaunchTemplate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `AwsSdk.EC2` the ability to move a launch template's default version, so a caller can decide which version an auto scaling group launches.

**Architecture:** One public function in the module's existing shape — positional required inputs with guards, `opts` last, a `sandbox?/1` branch, a private `do_` function building the Query operation and parsing the XML reply, a sandbox delegate and setter. The reply is a `LaunchTemplate`, the same structure `describe_launch_templates` already parses, so that field list is extracted first and both parsers share it.

**Tech Stack:** Elixir, SweetXml (`xpath`/`~x`), ExUnit, SandboxRegistry.

**Why this exists:** `deployd` gives each blue/green colour its own launch template holding its own image, and the auto scaling groups launch `$Default`. Arming a colour means writing a version and then promoting it. `create_launch_template_version/3` does the writing; nothing can do the promoting. The full reasoning is in that repository at `docs/superpowers/specs/2026-08-10-a-colour-holds-its-own-release-design.md`. This operation is missing from the SDK on its own terms regardless — `AwsSdk.EC2` can describe launch templates and create versions of them, but cannot modify one.

## Global Constraints

From this repository's `CLAUDE.md`:

- Every input AWS requires is a **positional argument**. `opts` is always last, always `\\ []`, and carries only optional inputs plus credentials, region, endpoint overrides and the sandbox flag.
- Requiredness is enforced by a **guard on the function head**, never by a runtime check on the keyword list.
- Public functions check `sandbox?(opts)` first and delegate to the `Sandbox` module when true.
- `do_*` functions are an explicit pipeline: `with {:ok, op} <- build_operation(...), {:ok, %{body: body}} <- Client.request(op) do ... end`.
- `AwsSdk.EC2` builds params with `maybe_put/3` and parses inline with SweetXml. Do not import `flatten_query/1` from the AutoScaling or ELBv2 modules.
- **Response fidelity is non-negotiable: nothing dropped, every documented member parsed.**
- The sandbox registry keys off the operation's first positional argument.
- `mix compile` runs with warnings-as-errors outside `:test`.
- Run `mix format` before committing.

## One decision this plan makes, so the implementer does not have to

AWS marks `DefaultVersion` **optional** on `ModifyLaunchTemplate`. This plan makes it a **positional, guarded argument** anyway, because it is the only thing the operation can change: a modify that changes nothing is not an operation worth exposing. That is a deliberate tightening of AWS's contract, not an oversight, and the `@doc` says so.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/aws_sdk/ec2.ex` | The extracted field list, the public function, its `do_` pipeline, the response parser, the sandbox delegate and fallback |
| `lib/aws_sdk/ec2/sandbox.ex` | The `modify_launch_template_response/2` entry and its setter |
| `test/aws_sdk/ec2/sandbox_test.exs` | Behaviour through the public function with the sandbox enabled |
| `test/aws_sdk/conformance_test.exs` | The parser against a real-shaped reply |

---

### Task 1: One field list, two operations

`describe_launch_templates` parses a `LaunchTemplate` inline. `ModifyLaunchTemplate` returns the same structure. Extracting the field list first means the two cannot disagree.

This is not tidiness. The last operation added to this module shipped a parser that omitted `operator` while its sibling parsed it, because the two field lists were written separately. Extraction removes the opportunity rather than relying on care.

**Files:**
- Modify: `lib/aws_sdk/ec2.ex` — `parse_describe_launch_templates/1` around line 3130

**Interfaces:**
- Produces: `launch_template_fields/0`, a private function returning the keyword list of xpath specs for one `LaunchTemplate` element, in the shape `launch_template_data_fields/0` already uses.

- [ ] **Step 1: Read the existing pair to copy the shape**

Run: `grep -n -A20 "defp launch_template_data_fields" lib/aws_sdk/ec2.ex | head -24`

Expected: a private zero-arity function returning a keyword list of xpath specs, spliced into a parser with `[~x"./someElement"o | launch_template_data_fields()]`.

- [ ] **Step 2: Extract the field list**

`parse_describe_launch_templates/1` currently reads:

```elixir
  defp parse_describe_launch_templates(body) do
    %{
      launch_templates:
        xpath(body, ~x"//launchTemplates/item"l,
          launch_template_id: ~x"./launchTemplateId/text()"s,
          launch_template_name: ~x"./launchTemplateName/text()"s,
          create_time: ~x"./createTime/text()"os,
          created_by: ~x"./createdBy/text()"os,
          default_version_number: ~x"./defaultVersionNumber/text()"oi,
          latest_version_number: ~x"./latestVersionNumber/text()"oi,
          operator: [
            ~x"./operator"o,
            managed: ~x"./managed/text()"os,
            principal: ~x"./principal/text()"os
          ],
          tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
        ),
```

Replace those field lines with a splice of the new function, leaving everything after the `xpath(...)` call — including the `next_token` line and the closing braces — exactly as it is:

```elixir
  defp parse_describe_launch_templates(body) do
    %{
      launch_templates:
        xpath(body, [~x"//launchTemplates/item"l | launch_template_fields()]),
```

Then add the function immediately after `parse_describe_launch_templates/1`, before whatever follows it:

```elixir
  # One LaunchTemplate, as both DescribeLaunchTemplates and
  # ModifyLaunchTemplate return it.
  defp launch_template_fields do
    [
      launch_template_id: ~x"./launchTemplateId/text()"s,
      launch_template_name: ~x"./launchTemplateName/text()"s,
      create_time: ~x"./createTime/text()"os,
      created_by: ~x"./createdBy/text()"os,
      default_version_number: ~x"./defaultVersionNumber/text()"oi,
      latest_version_number: ~x"./latestVersionNumber/text()"oi,
      operator: [
        ~x"./operator"o,
        managed: ~x"./managed/text()"os,
        principal: ~x"./principal/text()"os
      ],
      tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
    ]
  end
```

- [ ] **Step 3: Prove the extraction changed nothing**

Run: `mix test test/aws_sdk/conformance_test.exs`
Expected: PASS. `parse_describe_launch_templates_for_test/1` is exercised there against recorded XML, so a field lost or renamed in the move fails here.

- [ ] **Step 4: Run the whole suite**

Run: `mix test`
Expected: PASS, 394 tests, 0 failures — the count before this task.

- [ ] **Step 5: Compile and format**

Run: `mix compile --warnings-as-errors && mix format --check-formatted`
Expected: no errors. Run `mix format` first if the check complains.

- [ ] **Step 6: Commit**

```bash
git add lib/aws_sdk/ec2.ex
git commit -m "refactor: one field list for a launch template"
```

---

### Task 2: The sandbox entry and its setter

**Files:**
- Modify: `lib/aws_sdk/ec2/sandbox.ex`

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5` and `AwsSdk.Sandbox.register/4`.
- Produces:
  - `AwsSdk.EC2.Sandbox.modify_launch_template_response(launch_template_id, opts)`
  - `AwsSdk.EC2.Sandbox.set_modify_launch_template_responses(entries)`

- [ ] **Step 1: Add the entry beside the other launch template entries**

Find `create_launch_template_version_response` in `lib/aws_sdk/ec2/sandbox.ex` and add this directly after its `set_*_responses` counterpart, inside the same conditional block:

```elixir
    def modify_launch_template_response(launch_template_id, opts) do
      binding = [launch_template_id: launch_template_id, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :modify_launch_template, launch_template_id, binding)
    end

    def set_modify_launch_template_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :modify_launch_template, entries)
    end
```

- [ ] **Step 2: Compile**

Run: `mix compile`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/aws_sdk/ec2/sandbox.ex
git commit -m "feat: sandbox entry for modify_launch_template"
```

---

### Task 3: The operation

**Files:**
- Modify: `lib/aws_sdk/ec2.ex` — public function and `do_` pipeline beside `create_launch_template_version`, the delegate in the sandbox-delegation block, the fallback in the sandbox-unavailable block
- Test: `test/aws_sdk/ec2/sandbox_test.exs`
- Test: `test/aws_sdk/conformance_test.exs`

**Interfaces:**
- Consumes: `launch_template_fields/0` from Task 1, and `AwsSdk.EC2.Sandbox.modify_launch_template_response/2` from Task 2.
- Produces: `AwsSdk.EC2.modify_launch_template(launch_template_id, default_version, opts \\ [])` returning `{:ok, %{launch_template: map()}}` or `{:error, term()}`.

- [ ] **Step 1: Write the failing sandbox tests**

Add to `test/aws_sdk/ec2/sandbox_test.exs`, following the `describe` blocks already there:

```elixir
  describe "modify_launch_template/3" do
    test "returns the response registered for the launch template id" do
      Sandbox.set_modify_launch_template_responses([
        {"lt-1",
         fn ->
           {:ok,
            %{
              launch_template: %{
                launch_template_id: "lt-1",
                default_version_number: 3,
                latest_version_number: 7
              }
            }}
         end}
      ])

      assert {:ok,
              %{
                launch_template: %{
                  launch_template_id: "lt-1",
                  default_version_number: 3,
                  latest_version_number: 7
                }
              }} = EC2.modify_launch_template("lt-1", "3", sandbox: [enabled: true])
    end

    test "matches the launch template id by regex" do
      Sandbox.set_modify_launch_template_responses([
        {~r/^lt-/, fn -> {:ok, %{launch_template: %{default_version_number: 9}}} end}
      ])

      assert {:ok, %{launch_template: %{default_version_number: 9}}} =
               EC2.modify_launch_template("lt-matched", "9", sandbox: [enabled: true])
    end

    test "passes the launch template id to a function that takes it" do
      Sandbox.set_modify_launch_template_responses([
        {"lt-1",
         fn launch_template_id ->
           {:ok, %{launch_template: %{launch_template_id: launch_template_id}}}
         end}
      ])

      assert {:ok, %{launch_template: %{launch_template_id: "lt-1"}}} =
               EC2.modify_launch_template("lt-1", "3", sandbox: [enabled: true])
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/aws_sdk/ec2/sandbox_test.exs`
Expected: FAIL — `function AwsSdk.EC2.modify_launch_template/3 is undefined or private`.

- [ ] **Step 3: Add the public function and its pipeline**

In `lib/aws_sdk/ec2.ex`, directly after `parse_create_launch_template_version/1`, add:

```elixir
  @doc """
  Moves a launch template's default version.

  AWS marks `DefaultVersion` optional on this operation. It is required here:
  it is the only thing the operation changes, and a modify that changes nothing
  is not worth making.

  `default_version` is the version number as a string, or `"$Latest"` or
  `"$Default"`.

  ## Examples

      AwsSdk.EC2.modify_launch_template("lt-0a1b2c3d", "3")
      #=> {:ok,
      #=>  %{
      #=>    launch_template: %{
      #=>      launch_template_id: "lt-0a1b2c3d",
      #=>      default_version_number: 3,
      #=>      latest_version_number: 7
      #=>    }
      #=>  }}

  An auto scaling group launching `$Default` reads what this sets, so moving
  the default is what puts a version in front of the next instance a group
  starts. A group launching `$Latest` ignores it.

  ## Options

    * `:client_token` - a unique string making the call idempotent, so a retry
      after a timeout does not move the default twice.
  """
  @spec modify_launch_template(
          launch_template_id :: String.t(),
          default_version :: String.t(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def modify_launch_template(launch_template_id, default_version, opts \\ [])
      when is_binary(launch_template_id) and is_binary(default_version) do
    if sandbox?(opts) do
      sandbox_modify_launch_template_response(launch_template_id, opts)
    else
      do_modify_launch_template(launch_template_id, default_version, opts)
    end
  end

  defp do_modify_launch_template(launch_template_id, default_version, opts) do
    params =
      %{"LaunchTemplateId" => launch_template_id, "DefaultVersion" => default_version}
      |> maybe_put("ClientToken", opts[:client_token])

    with {:ok, op} <- build_operation("ModifyLaunchTemplate", params, opts),
         {:ok, %{body: body}} <- Client.request(op) do
      {:ok, parse_modify_launch_template(body)}
    end
  end

  @doc false
  def parse_modify_launch_template_for_test(xml), do: parse_modify_launch_template(xml)

  defp parse_modify_launch_template(body) do
    %{
      launch_template:
        xpath(
          body,
          [~x"//ModifyLaunchTemplateResponse/launchTemplate"o | launch_template_fields()]
        )
    }
  end
```

- [ ] **Step 4: Add the sandbox delegate**

In the run of `defdelegate sandbox_*_response` clauses, add directly after `sandbox_create_launch_template_version_response`:

```elixir
    @doc false
    defdelegate sandbox_modify_launch_template_response(launch_template_id, opts),
      to: AwsSdk.EC2.Sandbox,
      as: :modify_launch_template_response
```

- [ ] **Step 5: Add the sandbox-unavailable fallback**

In the block of `defp sandbox_*_response(_), do: raise("sandbox not available")` clauses, add directly after `sandbox_create_launch_template_version_response`:

```elixir
    defp sandbox_modify_launch_template_response(_, _),
      do: raise("sandbox not available")
```

- [ ] **Step 6: Run the sandbox tests to verify they pass**

Run: `mix test test/aws_sdk/ec2/sandbox_test.exs`
Expected: PASS, including the three new tests.

- [ ] **Step 7: Write the conformance test**

The sandbox tests short-circuit before the parser, so the parser has no coverage without this. Add to `test/aws_sdk/conformance_test.exs`, mirroring the `CreateLaunchTemplateVersion` test already there:

```elixir
  test "ModifyLaunchTemplate reads the template whose default moved" do
    xml = """
    <ModifyLaunchTemplateResponse>
      <requestId>59dbff89-35bd-4eac-99ed-be587EXAMPLE</requestId>
      <launchTemplate>
        <launchTemplateId>lt-0a1b2c3d4e5f6a7b8</launchTemplateId>
        <launchTemplateName>deployd-cylk-web-dev-blue</launchTemplateName>
        <createTime>2026-08-10T17:29:15.000Z</createTime>
        <createdBy>arn:aws:sts::291093735280:assumed-role/deploy/session</createdBy>
        <defaultVersionNumber>3</defaultVersionNumber>
        <latestVersionNumber>7</latestVersionNumber>
        <operator>
          <managed>true</managed>
          <principal>ec2.amazonaws.com</principal>
        </operator>
        <tagSet>
          <item>
            <key>Colour</key>
            <value>blue</value>
          </item>
        </tagSet>
      </launchTemplate>
    </ModifyLaunchTemplateResponse>
    """

    assert %{
             launch_template: %{
               launch_template_id: "lt-0a1b2c3d4e5f6a7b8",
               launch_template_name: "deployd-cylk-web-dev-blue",
               create_time: "2026-08-10T17:29:15.000Z",
               created_by: "arn:aws:sts::291093735280:assumed-role/deploy/session",
               default_version_number: 3,
               latest_version_number: 7,
               operator: %{managed: "true", principal: "ec2.amazonaws.com"},
               tag_set: [%{key: "Colour", value: "blue"}]
             }
           } == AwsSdk.EC2.parse_modify_launch_template_for_test(xml)
  end
```

Assert the whole parsed result, as written. A fragment asserted here is how a dropped member ships.

- [ ] **Step 8: Run the conformance tests**

Run: `mix test test/aws_sdk/conformance_test.exs`
Expected: PASS.

If a field comes back as `""` where the test expects a value, or `nil` where it expects a map, the xpath is wrong — fix the parser, not the expectation.

- [ ] **Step 9: Compile, format, and run the whole suite**

Run: `mix compile --warnings-as-errors && mix format --check-formatted && mix test`
Expected: no errors, and 398 tests, 0 failures — 394 before this plan, plus three sandbox tests and one conformance test.

- [ ] **Step 10: Commit**

```bash
git add lib/aws_sdk/ec2.ex test/aws_sdk/ec2/sandbox_test.exs test/aws_sdk/conformance_test.exs
git commit -m "feat: EC2 moves a launch template's default version"
```

---

### Task 4: Publish a ref deployd can pin

**Files:**
- None. This task publishes and reports.

**Interfaces:**
- Consumes: the commits from Tasks 1 to 3.
- Produces: a commit SHA on `origin/main` for deployd's `mix.exs` to pin.

- [ ] **Step 1: Confirm the working tree is clean and the suite passes**

Run: `git status --short && mix test`
Expected: no output from `git status`, and 398 tests, 0 failures.

- [ ] **Step 2: Check what the push would publish**

Run: `git log --oneline origin/main..HEAD`

Expected: only the commits from this plan. `origin/main` was left at `d7fcd55` by the previous plan, so anything else appearing here is unpushed work from another line and is worth reporting before pushing rather than after.

- [ ] **Step 3: Push**

```bash
git push origin main
```

- [ ] **Step 4: Record the ref**

Run: `git rev-parse HEAD`

Report that SHA. deployd pins it in `mix.exs`, replacing `d7fcd55a46d5005922f51ecb8fa9237cb8eb7221`, and runs its own suite against it — the previous bump surfaced a real incompatibility, so the bump is verified rather than assumed.

---

## Notes for the implementer

- **Task 1 is the point of this plan as much as Task 3.** The last operation added here shipped a parser that dropped `operator` while its sibling kept it, because two field lists were maintained by hand. After Task 1 there is one list, and a member added to it appears in both operations at once.
- **`default_version` is a string, not an integer.** AWS accepts `"3"`, `"$Latest"` and `"$Default"`, so the parameter is a string even when it looks like a number. The parsed reply's `default_version_number` is an integer, because that is what AWS sends back — input takes AWS's spelling, output is parsed to Elixir's, which is this module's existing asymmetry.
- **The parser anchors to `//ModifyLaunchTemplateResponse/launchTemplate`.** CLAUDE.md requires selectors anchored to their result element; an unanchored `//launchTemplate` would also match a `launchTemplate` nested anywhere else a future response shape puts one.
- **There is no `modify_launch_template_by_name`.** AWS accepts a name instead of an id, and this repository exposes mutually exclusive inputs as separate named functions. Only the id form is needed, so only it is built.
