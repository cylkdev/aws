# NEXT.md Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement every operation in NEXT.md (the deployd backlog) across the existing SSM, EC2, AutoScaling, ElasticLoadBalancingV2, IAM, and S3 modules, per the approved spec `docs/superpowers/specs/2026-08-05-nextmd-operations-design.md`.

**Architecture:** Each operation is one public function added to an existing service module following the `e44e734` pattern: public fn with `sandbox?/1` branch, `do_*` private impl (params → explicit `build_operation` + `Client.request` `with` pipeline → parse), full-fidelity response parsing, `defdelegate sandbox_<op>_response`, and the `<op>_response`/`set_<op>_responses` pair in the service's Sandbox module. No new modules; new code lands in existing modules (including `AwsSdk.S3.XMLBuilder.build_delete/2` and `AwsSdk.S3.XMLParser.parse_delete_result/1`).

**Tech Stack:** Elixir, SweetXml (XML parsing), Erlang `:json` (JSON 1.1 protocol), SandboxRegistry (test sandbox), ExUnit.

## Global Constraints

- **Prerequisite:** this plan assumes `docs/superpowers/plans/2026-08-05-client-request-refactor.md` is fully merged — `AwsSdk.Client.request/1` exists and no service module retains `perform`/`deserialize_response`. Do not start Task 1 before that.
- `mix compile` is warnings-as-errors outside test. Run `mix compile`, `mix test`, and `mix format` before every commit; all must be clean.
- **Response fidelity (from CLAUDE.md, non-negotiable):** parsers extract fields, never redesign. Nesting preserved (`<placement><groupName>` → `placement: %{group_name: ...}`); member names preserved as snake_case of the AWS name (no renaming, no synthesized keys); `<xxxSet><item>` → `xxx_set: [%{...}]` (the `Set` suffix stays); nothing dropped including `next_token`; only the outer `<XxxResponse>`/`<XxxResult>` envelope and RequestId metadata are omitted.
- **Timestamps stay ISO8601 strings** in the XML services. This matches the codebase (`e44e734` keeps `createTime` as `os`; AutoScaling keeps `StartTime` as `s`; IAM keeps `create_date` as a string). CLAUDE.md's general leaf-coercion note notwithstanding, do NOT parse timestamps into `DateTime` structs — the module convention wins.
- **Booleans:** each task's coercer names exactly the boolean members it coerces; every other boolean member stays a wire string, matching `e44e734`'s `launchTemplateData` (which leaves nested booleans as strings). Coerced members AWS always returns are read `s` and coerced `=== "true"` (mirror `coerce_is_default/1`, `ec2.ex:643`, which also reads `s`); genuinely optional ones (`networkPathFound`) are read `os` with a nil-preserving coercer clause. EC2 coercers are named `coerce_<field>/1` for a single field or `coerce_<entity>/1` when one item needs several fields coerced, applied with `Enum.map`; S3's `XMLParser` uses the existing `to_bool/1`. The one precedented inline coercion is `parse_return/1`'s `== "true"` on a bare `<return>` scalar — `parse_delete_key_pair/1` mirrors it. Do not introduce new coercion helpers where one exists.
- XML list selectors anchor at the set element, exactly as EC2 already does (`~x"//snapshotSet/item"l`, matching `~x"//vpcSet/item"l` at `ec2.ex:596` and `~x"//launchTemplates/item"l` at `ec2.ex:1448`) — never a bare `~x"//item"l`. Scalars like `next_token` stay response-anchored (`~x"//DescribeSnapshotsResponse/nextToken/text()"os`, per the `e44e734` precedent). AutoScaling/ELBv2/IAM anchor at their `<XxxResult>` element with `e`, as their existing parsers do. Nested singletons use an optional anchor (`~x"./ebs"o`) so absent structures parse to `nil`.
- **Model drift:** before committing each EC2 describe, diff the parser's keyword list against the current botocore model for that response shape and add any documented member this plan missed — the fidelity rule binds to the live model, not to this document.
- Sandbox registry key = the operation's first positional argument. When the first positional argument is a list, or the op has only `opts`, the key is `"*"` and `set_*_responses` accepts bare `fn`s (mirrors `AwsSdk.SSM.Sandbox.get_parameters_response/2`).
- Commit messages: conventional (`feat: ...`), body explains what/why, ending with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- SSM (JSON 1.1) responses are deserialized generically by `ExUtils.Serializer` — SSM ops have **no hand-written parser and no conformance test**; they get sandbox tests only. XML ops (EC2, AutoScaling, ELBv2, IAM, S3) each get a fixture-backed conformance test in `test/aws_sdk/conformance_test.exs` plus sandbox tests.
- Every new public function gets a `@doc` with an `## Examples` section showing a realistic request and the full response shape (matching the documentation style already in each module), and a `@spec`.

### Standard wiring recipe A — SSM (JSON 1.1) op

Used by Tasks 1–3; its sandbox half is reused by Tasks 15–18 with each module's own naming (noted per task — e.g. AutoScaling abbreviates the group-name argument as `asg`). For an op named `<op>` (AWS action `<Action>`), the pieces are, with only the marked parts varying per task:

In `lib/aws_sdk/ssm.ex`, in the section indicated by the task — public fn + `do_` impl (task supplies signature, guard, and data map):

```elixir
def <op>(<positional args>, opts \\ []) <task-specified guard> do
  if sandbox?(opts) do
    sandbox_<op>_response(<positional args>, opts)
  else
    do_<op>(<positional args>, opts)
  end
end

defp do_<op>(<positional args>, opts) do
  data = <task-specified data map, built with maybe_put/3>

  with {:ok, op} <- build_operation("<Action>", data, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, Serializer.deserialize(decode_body(body), deserialize_opts(opts))}
  end
end
```

In the `if Code.ensure_loaded?(SandboxRegistry)` block of `lib/aws_sdk/ssm.ex`, after the existing delegates:

```elixir
@doc false
defdelegate sandbox_<op>_response(<positional args>, opts),
  to: AwsSdk.SSM.Sandbox,
  as: :<op>_response
```

And in the `else` branch, matching arity:

```elixir
defp sandbox_<op>_response(<underscored args>, _), do: raise("sandbox not available")
```

That one-line raise is SSM/EC2's stub style. AutoScaling raises its `@sandbox_unavailable` module attribute with `(_a, _o)`-style args, and S3's stubs are full functions raising a heredoc — Tasks 15 and 18 show their modules' exact forms.

In `lib/aws_sdk/ssm/sandbox.ex` (task supplies the key expression — the first positional arg, or `"*"` when that arg is a list):

```elixir
def <op>_response(<positional args>, opts) do
  examples = AwsSdk.Sandbox.doc_examples([<positional arg names as atoms>])
  func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :<op>, <key expr>, examples)
  AwsSdk.Sandbox.apply_func(func, [<positional args>, opts], examples)
end

def set_<op>_responses(tuples) do
  AwsSdk.Sandbox.set_responses(
    @registry,
    __MODULE__,
    :<op>,
    AwsSdk.Sandbox.normalize_no_key(tuples)
  )
end
```

### Standard wiring recipe B — EC2 (Query/XML) op

Used by Tasks 4–14. Same shape as recipe A with these differences: the `do_` impl builds `params` with `maybe_put/3`, `put_member_list/3`, `put_filters/2` (all already exist in `lib/aws_sdk/ec2.ex`), ends in `with {:ok, op} <- build_operation("<Action>", params, opts), {:ok, %{body: body}} <- Client.request(op) do {:ok, parse_<op>(body)} end`, and each op adds:

```elixir
@doc false
def parse_<op>_for_test(xml), do: parse_<op>(xml)

defp parse_<op>(body) do
  <task-specified xpath extraction>
end
```

Sandbox delegates live in `lib/aws_sdk/ec2.ex`'s `if Code.ensure_loaded?(SandboxRegistry)` block (with matching `else` stubs), and the response/set pair in `lib/aws_sdk/ec2/sandbox.ex`, exactly as in recipe A. `ec2.ex` already has `import SweetXml, only: [xpath: 2, xpath: 3, sigil_x: 2]`.

AutoScaling (Task 15), ELBv2 (Task 16), and IAM (Task 17) follow the same recipe with their modules' own helpers: AutoScaling/ELBv2 build params with `flatten_query/1` and use extracted `parse_*/1` functions; IAM builds a params map merged with `Action`/`Version` by its own `build_operation`. S3 (Task 18) differs only in `build_operation(method, bucket, key, opts)` — its operation identity is the HTTP method + URL, not an `Action` param.

---

### Task 1: SSM `send_command` + `send_command_by_targets`

**Files:**
- Modify: `lib/aws_sdk/ssm.ex` (new "Run Command" section after the Managed instances section, plus sandbox delegation block)
- Modify: `lib/aws_sdk/ssm/sandbox.ex`
- Test: `test/aws_sdk/ssm/sandbox_test.exs`

**Interfaces:**
- Consumes: existing `build_operation/3`, `Client.request/1`, `decode_body/1`, `deserialize_opts/1`, `maybe_put/3`, `sandbox?/1` in `ssm.ex`; `AwsSdk.Sandbox` helpers.
- Produces: `AwsSdk.SSM.send_command(instance_ids :: [String.t()], document_name :: String.t(), opts :: keyword()) :: {:ok, %{command: map()}} | {:error, term()}`; `AwsSdk.SSM.send_command_by_targets(targets :: [map()], document_name :: String.t(), opts :: keyword())` with the same return; `AwsSdk.SSM.Sandbox.set_send_command_responses/1` and `set_send_command_by_targets_responses/1` (bare-`fn` tuples, key `"*"`).

- [ ] **Step 1: Write the failing sandbox tests**

Append to `test/aws_sdk/ssm/sandbox_test.exs` (inside the existing top-level `describe`-per-op layout; alias `AwsSdk.SSM` and `AwsSdk.SSM.Sandbox` are already in the file):

```elixir
describe "send_command/3" do
  test "returns the registered command" do
    Sandbox.set_send_command_responses([
      fn ->
        {:ok,
         %{
           command: %{
             command_id: "cmd-123",
             document_name: "AWS-RunShellScript",
             instance_ids: ["i-1"],
             status: "Pending"
           }
         }}
      end
    ])

    assert {:ok, %{command: %{command_id: "cmd-123"}}} =
             SSM.send_command(["i-1"], "AWS-RunShellScript",
               parameters: %{"commands" => ["uptime"]},
               sandbox: [enabled: true]
             )
  end
end

describe "send_command_by_targets/3" do
  test "returns the registered command" do
    Sandbox.set_send_command_by_targets_responses([
      fn -> {:ok, %{command: %{command_id: "cmd-456", status: "Pending"}}} end
    ])

    assert {:ok, %{command: %{command_id: "cmd-456"}}} =
             SSM.send_command_by_targets(
               [%{key: "tag:Role", values: ["web"]}],
               "AWS-RunShellScript",
               sandbox: [enabled: true]
             )
  end
end
```

Match the file's actual alias names when appending (open the file first; if it uses `AwsSdk.SSM` unaliased, follow that).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/aws_sdk/ssm/sandbox_test.exs`
Expected: FAIL with `undefined function set_send_command_responses/1` (or `send_command/3`).

- [ ] **Step 3: Implement**

In `lib/aws_sdk/ssm.ex`, add a new section after the Managed instances section:

```elixir
# ---------------------------------------------------------------------------
# Run Command
# ---------------------------------------------------------------------------

@doc """
Runs a command on the specified managed nodes.

## Arguments

  * `instance_ids` - A list of 1-50 managed node IDs.
  * `document_name` - The SSM document to run (e.g. `"AWS-RunShellScript"`).
  * `opts` - Options:
    * `:parameters` - Map of document parameters, e.g.
      `%{"commands" => ["uptime"]}`.
    * `:comment` - User-specified information about the command.
    * `:timeout_seconds` - Seconds to wait for a node to begin running
      the command (30-2592000).
    * `:document_version` - Document version (`"$DEFAULT"`, `"$LATEST"`,
      or a version number string).
    * `:output_s3_bucket_name`, `:output_s3_key_prefix` - Where to store
      full command output.
    * `:cloud_watch_output_config` - Map with PascalCase keys, e.g.
      `%{"CloudWatchOutputEnabled" => true}`.
    * `:max_concurrency`, `:max_errors` - Rate controls.
    * `:service_role_arn`, `:notification_config` - SNS notifications.

## Examples

    AwsSdk.SSM.send_command(["i-1234567890abcdef0"], "AWS-RunShellScript",
      parameters: %{"commands" => ["systemctl restart app"]}
    )
    #=> {:ok,
    #=>  %{
    #=>    command: %{
    #=>      command_id: "0831e1a8-4c47-4c74-8f2a-EXAMPLE",
    #=>      document_name: "AWS-RunShellScript",
    #=>      instance_ids: ["i-1234567890abcdef0"],
    #=>      status: "Pending",
    #=>      status_details: "Pending",
    #=>      requested_date_time: 1.7e9,
    #=>      expires_after: 1.7e9,
    #=>      parameters: %{commands: ["systemctl restart app"]},
    #=>      output_s3_bucket_name: "",
    #=>      output_s3_key_prefix: ""
    #=>    }
    #=>  }}

Poll the result with `get_command_invocation/3` using `:command_id`.
To target by tags or resource groups instead of explicit instance IDs,
use `send_command_by_targets/3`.
"""
@spec send_command(instance_ids :: [String.t()], document_name :: String.t(), opts :: keyword()) ::
        {:ok, %{command: map()}} | {:error, term()}
def send_command([_ | _] = instance_ids, document_name, opts \\ [])
    when is_binary(document_name) do
  if sandbox?(opts) do
    sandbox_send_command_response(instance_ids, document_name, opts)
  else
    do_send_command(instance_ids, document_name, opts)
  end
end

defp do_send_command(instance_ids, document_name, opts) do
  data =
    %{"InstanceIds" => instance_ids, "DocumentName" => document_name}
    |> maybe_put("Parameters", opts[:parameters])
    |> maybe_put("Comment", opts[:comment])
    |> maybe_put("TimeoutSeconds", opts[:timeout_seconds])
    |> maybe_put("DocumentVersion", opts[:document_version])
    |> maybe_put("DocumentHash", opts[:document_hash])
    |> maybe_put("DocumentHashType", opts[:document_hash_type])
    |> maybe_put("OutputS3BucketName", opts[:output_s3_bucket_name])
    |> maybe_put("OutputS3KeyPrefix", opts[:output_s3_key_prefix])
    |> maybe_put("CloudWatchOutputConfig", opts[:cloud_watch_output_config])
    |> maybe_put("MaxConcurrency", opts[:max_concurrency])
    |> maybe_put("MaxErrors", opts[:max_errors])
    |> maybe_put("ServiceRoleArn", opts[:service_role_arn])
    |> maybe_put("NotificationConfig", opts[:notification_config])

  with {:ok, op} <- build_operation("SendCommand", data, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, Serializer.deserialize(decode_body(body), deserialize_opts(opts))}
  end
end

@doc """
Runs a command on nodes selected by targets (tag or resource-group
criteria) instead of explicit instance IDs.

AWS `SendCommand` accepts exactly one of `InstanceIds` or `Targets`;
this is the `Targets` form of `send_command/3`.

## Arguments

  * `targets` - List of `%{key:, values:}` maps, e.g.
    `[%{key: "tag:Role", values: ["web"]}]` — encoded to the wire's
    `Key`/`Values`, like EC2's `%{name:, values:}` filters.
  * `document_name` - The SSM document to run.
  * `opts` - Same options as `send_command/3`.

## Examples

    AwsSdk.SSM.send_command_by_targets(
      [%{key: "tag:Role", values: ["web"]}],
      "AWS-RunShellScript",
      parameters: %{"commands" => ["uptime"]}
    )
    #=> {:ok, %{command: %{command_id: "0831e1a8-...", status: "Pending"}}}
"""
@spec send_command_by_targets(targets :: [map()], document_name :: String.t(), opts :: keyword()) ::
        {:ok, %{command: map()}} | {:error, term()}
def send_command_by_targets([_ | _] = targets, document_name, opts \\ [])
    when is_binary(document_name) do
  if sandbox?(opts) do
    sandbox_send_command_by_targets_response(targets, document_name, opts)
  else
    do_send_command_by_targets(targets, document_name, opts)
  end
end

defp do_send_command_by_targets(targets, document_name, opts) do
  wire_targets =
    Enum.map(targets, fn %{key: key, values: values} -> %{"Key" => key, "Values" => values} end)

  data =
    %{"Targets" => wire_targets, "DocumentName" => document_name}
    |> maybe_put("Parameters", opts[:parameters])
    |> maybe_put("Comment", opts[:comment])
    |> maybe_put("TimeoutSeconds", opts[:timeout_seconds])
    |> maybe_put("DocumentVersion", opts[:document_version])
    |> maybe_put("DocumentHash", opts[:document_hash])
    |> maybe_put("DocumentHashType", opts[:document_hash_type])
    |> maybe_put("OutputS3BucketName", opts[:output_s3_bucket_name])
    |> maybe_put("OutputS3KeyPrefix", opts[:output_s3_key_prefix])
    |> maybe_put("CloudWatchOutputConfig", opts[:cloud_watch_output_config])
    |> maybe_put("MaxConcurrency", opts[:max_concurrency])
    |> maybe_put("MaxErrors", opts[:max_errors])
    |> maybe_put("ServiceRoleArn", opts[:service_role_arn])
    |> maybe_put("NotificationConfig", opts[:notification_config])

  with {:ok, op} <- build_operation("SendCommand", data, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, Serializer.deserialize(decode_body(body), deserialize_opts(opts))}
  end
end
```

(The `maybe_put` chain is repeated in both `do_` functions on purpose — SSM inlines its optional-input encoding per function; the module has no shared opts-builder helpers and this task does not introduce one.)

Wire the sandbox per recipe A. Delegates in `ssm.ex`:

```elixir
@doc false
defdelegate sandbox_send_command_response(instance_ids, document_name, opts),
  to: AwsSdk.SSM.Sandbox,
  as: :send_command_response

@doc false
defdelegate sandbox_send_command_by_targets_response(targets, document_name, opts),
  to: AwsSdk.SSM.Sandbox,
  as: :send_command_by_targets_response
```

`else`-branch stubs:

```elixir
defp sandbox_send_command_response(_, _, _), do: raise("sandbox not available")
defp sandbox_send_command_by_targets_response(_, _, _), do: raise("sandbox not available")
```

In `lib/aws_sdk/ssm/sandbox.ex` (key `"*"` — the first positional arg is a list):

```elixir
def send_command_response(instance_ids, document_name, opts) do
  examples = AwsSdk.Sandbox.doc_examples([:instance_ids, :document_name])
  func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :send_command, "*", examples)
  AwsSdk.Sandbox.apply_func(func, [instance_ids, document_name, opts], examples)
end

def set_send_command_responses(tuples) do
  AwsSdk.Sandbox.set_responses(
    @registry,
    __MODULE__,
    :send_command,
    AwsSdk.Sandbox.normalize_no_key(tuples)
  )
end

def send_command_by_targets_response(targets, document_name, opts) do
  examples = AwsSdk.Sandbox.doc_examples([:targets, :document_name])
  func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :send_command_by_targets, "*", examples)
  AwsSdk.Sandbox.apply_func(func, [targets, document_name, opts], examples)
end

def set_send_command_by_targets_responses(tuples) do
  AwsSdk.Sandbox.set_responses(
    @registry,
    __MODULE__,
    :send_command_by_targets,
    AwsSdk.Sandbox.normalize_no_key(tuples)
  )
end
```

- [ ] **Step 4: Verify**

Run: `mix compile && mix test test/aws_sdk/ssm/sandbox_test.exs && mix format --check-formatted || mix format`
Expected: compile clean, tests PASS. Then run the full suite: `mix test` — all green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ssm.ex lib/aws_sdk/ssm/sandbox.ex test/aws_sdk/ssm/sandbox_test.exs
git commit -m "feat: SSM SendCommand by instance ids and by targets"
```

(Include the standard commit body and Co-Authored-By trailer.)

---

### Task 2: SSM `get_command_invocation`

**Files:**
- Modify: `lib/aws_sdk/ssm.ex` (Run Command section from Task 1; if absent, create it in the same position)
- Modify: `lib/aws_sdk/ssm/sandbox.ex`
- Test: `test/aws_sdk/ssm/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `decode_body/1`, `deserialize_opts/1`, `maybe_put/3`, `sandbox?/1`.
- Produces: `AwsSdk.SSM.get_command_invocation(command_id :: String.t(), instance_id :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}`; `AwsSdk.SSM.Sandbox.set_get_command_invocation_responses/1` taking `{command_id_or_regex, fun}` tuples.

- [ ] **Step 1: Write the failing sandbox test**

```elixir
describe "get_command_invocation/3" do
  test "keys off the command id" do
    Sandbox.set_get_command_invocation_responses([
      {"cmd-123",
       fn ->
         {:ok,
          %{
            command_id: "cmd-123",
            instance_id: "i-1",
            status: "Success",
            status_details: "Success",
            response_code: 0,
            standard_output_content: "ok\n",
            standard_error_content: ""
          }}
       end}
    ])

    assert {:ok, %{status: "Success", standard_output_content: "ok\n"}} =
             SSM.get_command_invocation("cmd-123", "i-1", sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/aws_sdk/ssm/sandbox_test.exs`
Expected: FAIL with undefined function.

- [ ] **Step 3: Implement**

```elixir
@doc """
Returns detailed information about a command a specific node ran.

deployd's polling loop: call until `:status` leaves `"Pending"`/
`"InProgress"`/`"Delayed"`; treat `"Success"` as pass and `"Failed"`,
`"Cancelled"`, or `"TimedOut"` as failure.

## Arguments

  * `command_id` - The parent command's ID (from `send_command/3`).
  * `instance_id` - The managed node the command ran on.
  * `opts` - Options:
    * `:plugin_name` - Name of the step/plugin for multi-plugin documents.

## Examples

    AwsSdk.SSM.get_command_invocation("0831e1a8-4c47-4c74-8f2a-EXAMPLE", "i-1234567890abcdef0")
    #=> {:ok,
    #=>  %{
    #=>    command_id: "0831e1a8-4c47-4c74-8f2a-EXAMPLE",
    #=>    instance_id: "i-1234567890abcdef0",
    #=>    document_name: "AWS-RunShellScript",
    #=>    document_version: "$DEFAULT",
    #=>    plugin_name: "aws:runShellScript",
    #=>    response_code: 0,
    #=>    execution_start_date_time: "2026-08-05T12:00:00.000Z",
    #=>    execution_elapsed_time: "PT0.5S",
    #=>    execution_end_date_time: "2026-08-05T12:00:01.000Z",
    #=>    status: "Success",
    #=>    status_details: "Success",
    #=>    standard_output_content: "ok\\n",
    #=>    standard_output_url: "",
    #=>    standard_error_content: "",
    #=>    standard_error_url: "",
    #=>    cloud_watch_output_config: %{
    #=>      cloud_watch_log_group_name: "",
    #=>      cloud_watch_output_enabled: false
    #=>    },
    #=>    comment: ""
    #=>  }}
"""
@spec get_command_invocation(command_id :: String.t(), instance_id :: String.t(), opts :: keyword()) ::
        {:ok, map()} | {:error, term()}
def get_command_invocation(command_id, instance_id, opts \\ [])
    when is_binary(command_id) and is_binary(instance_id) do
  if sandbox?(opts) do
    sandbox_get_command_invocation_response(command_id, instance_id, opts)
  else
    do_get_command_invocation(command_id, instance_id, opts)
  end
end

defp do_get_command_invocation(command_id, instance_id, opts) do
  data =
    %{"CommandId" => command_id, "InstanceId" => instance_id}
    |> maybe_put("PluginName", opts[:plugin_name])

  with {:ok, op} <- build_operation("GetCommandInvocation", data, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, Serializer.deserialize(decode_body(body), deserialize_opts(opts))}
  end
end
```

Sandbox wiring per recipe A — delegate `sandbox_get_command_invocation_response(command_id, instance_id, opts)` / stub `(_, _, _)`, and in `ssm/sandbox.ex` the pair keyed off `command_id`:

```elixir
def get_command_invocation_response(command_id, instance_id, opts) do
  examples = AwsSdk.Sandbox.doc_examples([:command_id, :instance_id])
  func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :get_command_invocation, command_id, examples)
  AwsSdk.Sandbox.apply_func(func, [command_id, instance_id, opts], examples)
end

def set_get_command_invocation_responses(tuples) do
  AwsSdk.Sandbox.set_responses(
    @registry,
    __MODULE__,
    :get_command_invocation,
    AwsSdk.Sandbox.normalize_no_key(tuples)
  )
end
```

- [ ] **Step 4: Verify**

Run: `mix compile && mix test && mix format`
Expected: clean compile, all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ssm.ex lib/aws_sdk/ssm/sandbox.ex test/aws_sdk/ssm/sandbox_test.exs
git commit -m "feat: SSM GetCommandInvocation"
```

---

### Task 3: SSM `list_command_invocations`

**Files:**
- Modify: `lib/aws_sdk/ssm.ex`, `lib/aws_sdk/ssm/sandbox.ex`
- Test: `test/aws_sdk/ssm/sandbox_test.exs`

**Interfaces:**
- Consumes: same SSM helpers as Tasks 1–2.
- Produces: `AwsSdk.SSM.list_command_invocations(opts :: keyword()) :: {:ok, %{command_invocations: [map()], next_token: String.t() | nil}} | {:error, term()}`; `AwsSdk.SSM.Sandbox.set_list_command_invocations_responses/1` (bare `fn`s, key `"*"`).

- [ ] **Step 1: Write the failing sandbox test**

```elixir
describe "list_command_invocations/1" do
  test "returns the registered invocations" do
    Sandbox.set_list_command_invocations_responses([
      fn ->
        {:ok,
         %{
           command_invocations: [
             %{command_id: "cmd-123", instance_id: "i-1", status: "Success"},
             %{command_id: "cmd-123", instance_id: "i-2", status: "InProgress"}
           ],
           next_token: nil
         }}
      end
    ])

    assert {:ok, %{command_invocations: [_, _]}} =
             SSM.list_command_invocations(command_id: "cmd-123", sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/aws_sdk/ssm/sandbox_test.exs` — expected FAIL, undefined function.

- [ ] **Step 3: Implement**

```elixir
@doc """
Lists the invocations of a command across nodes — the fleet-wide view of
one `send_command/3` call.

## Options

  * `:command_id` - Restrict to one command's invocations.
  * `:instance_id` - Restrict to one node.
  * `:details` - Boolean; include per-plugin `command_plugins` detail.
  * `:filters` - List of `%{"key" => k, "value" => v}` maps
    (keys: `"InvokedAfter"`, `"InvokedBefore"`, `"Status"`, `"DocumentName"`).
  * `:max_results` - Integer page size (1-50).
  * `:next_token` - Pagination token.

## Examples

    AwsSdk.SSM.list_command_invocations(command_id: "0831e1a8-4c47-4c74-8f2a-EXAMPLE")
    #=> {:ok,
    #=>  %{
    #=>    command_invocations: [
    #=>      %{
    #=>        command_id: "0831e1a8-4c47-4c74-8f2a-EXAMPLE",
    #=>        instance_id: "i-1234567890abcdef0",
    #=>        instance_name: "",
    #=>        document_name: "AWS-RunShellScript",
    #=>        document_version: "$DEFAULT",
    #=>        requested_date_time: 1.7e9,
    #=>        status: "Success",
    #=>        status_details: "Success",
    #=>        command_plugins: [],
    #=>        service_role: "",
    #=>        notification_config: %{notification_arn: "", notification_events: [], notification_type: ""},
    #=>        cloud_watch_output_config: %{cloud_watch_log_group_name: "", cloud_watch_output_enabled: false}
    #=>      }
    #=>    ],
    #=>    next_token: nil
    #=>  }}
"""
@spec list_command_invocations(opts :: keyword()) ::
        {:ok, %{command_invocations: [map()], next_token: String.t() | nil}} | {:error, term()}
def list_command_invocations(opts \\ []) do
  if sandbox?(opts) do
    sandbox_list_command_invocations_response(opts)
  else
    do_list_command_invocations(opts)
  end
end

defp do_list_command_invocations(opts) do
  data =
    %{}
    |> maybe_put("CommandId", opts[:command_id])
    |> maybe_put("InstanceId", opts[:instance_id])
    |> maybe_put("Details", opts[:details])
    |> maybe_put("Filters", opts[:filters])
    |> maybe_put("MaxResults", opts[:max_results])
    |> maybe_put("NextToken", opts[:next_token])

  with {:ok, op} <- build_operation("ListCommandInvocations", data, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, Serializer.deserialize(decode_body(body), deserialize_opts(opts))}
  end
end
```

Sandbox wiring per recipe A, arity 1, key `"*"`:

```elixir
def list_command_invocations_response(opts) do
  examples = AwsSdk.Sandbox.doc_examples([])
  func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_command_invocations, "*", examples)
  AwsSdk.Sandbox.apply_func(func, [opts], examples)
end

def set_list_command_invocations_responses(tuples) do
  AwsSdk.Sandbox.set_responses(
    @registry,
    __MODULE__,
    :list_command_invocations,
    AwsSdk.Sandbox.normalize_no_key(tuples)
  )
end
```

Delegate `sandbox_list_command_invocations_response(opts)` / stub `(_)` in `ssm.ex`.

- [ ] **Step 4: Verify**

Run: `mix compile && mix test && mix format` — all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ssm.ex lib/aws_sdk/ssm/sandbox.ex test/aws_sdk/ssm/sandbox_test.exs
git commit -m "feat: SSM ListCommandInvocations"
```

---

### Task 4: EC2 `terminate_instances`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex` (new "Instance lifecycle" section near `describe_instances`; update the `@moduledoc` sentence "Instances are described but never launched or terminated here" to say termination is now included)
- Modify: `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `put_member_list/3` in `ec2.ex`.
- Produces: `AwsSdk.EC2.terminate_instances(instance_ids :: [String.t()], opts :: keyword()) :: {:ok, %{instances_set: [map()]}} | {:error, term()}`; `AwsSdk.EC2.parse_terminate_instances_for_test/1`; `AwsSdk.EC2.Sandbox.set_terminate_instances_responses/1` (bare `fn`s, key `"*"`).

- [ ] **Step 1: Write the failing tests**

Conformance (`test/aws_sdk/conformance_test.exs`):

```elixir
test "TerminateInstances keeps both states and integer state codes" do
  xml = """
  <TerminateInstancesResponse><instancesSet>
  <item><instanceId>i-1</instanceId>
  <currentState><code>32</code><name>shutting-down</name></currentState>
  <previousState><code>16</code><name>running</name></previousState></item>
  <item><instanceId>i-2</instanceId>
  <currentState><code>48</code><name>terminated</name></currentState>
  <previousState><code>64</code><name>stopping</name></previousState></item>
  </instancesSet></TerminateInstancesResponse>
  """

  parsed = AwsSdk.EC2.parse_terminate_instances_for_test(xml)

  assert [one, two] = parsed.instances_set
  assert one.instance_id == "i-1"
  assert one.current_state == %{code: 32, name: "shutting-down"}
  assert one.previous_state == %{code: 16, name: "running"}
  assert two.current_state.name == "terminated"
end
```

Sandbox (`test/aws_sdk/ec2/sandbox_test.exs`):

```elixir
describe "terminate_instances/2" do
  test "returns the registered state changes" do
    Sandbox.set_terminate_instances_responses([
      fn ->
        {:ok,
         %{
           instances_set: [
             %{
               instance_id: "i-1",
               current_state: %{code: 32, name: "shutting-down"},
               previous_state: %{code: 16, name: "running"}
             }
           ]
         }}
      end
    ])

    assert {:ok, %{instances_set: [%{instance_id: "i-1"}]}} =
             EC2.terminate_instances(["i-1"], sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs`
Expected: FAIL — undefined `parse_terminate_instances_for_test/1` and `set_terminate_instances_responses/1`.

- [ ] **Step 3: Implement**

```elixir
@doc """
Terminates the specified instances.

## Arguments

  * `instance_ids` - List of instance IDs, encoded as `InstanceId.N`.

## Examples

    AwsSdk.EC2.terminate_instances(["i-1234567890abcdef0"])
    #=> {:ok,
    #=>  %{
    #=>    instances_set: [
    #=>      %{
    #=>        instance_id: "i-1234567890abcdef0",
    #=>        current_state: %{code: 32, name: "shutting-down"},
    #=>        previous_state: %{code: 16, name: "running"}
    #=>      }
    #=>    ]
    #=>  }}
"""
@spec terminate_instances(instance_ids :: [String.t()], opts :: keyword()) ::
        {:ok, %{instances_set: list(map())}} | {:error, term()}
def terminate_instances([_ | _] = instance_ids, opts \\ []) do
  if sandbox?(opts) do
    sandbox_terminate_instances_response(instance_ids, opts)
  else
    do_terminate_instances(instance_ids, opts)
  end
end

defp do_terminate_instances(instance_ids, opts) do
  params = put_member_list(%{}, "InstanceId", instance_ids)

  with {:ok, op} <- build_operation("TerminateInstances", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_terminate_instances(body)}
  end
end

@doc false
def parse_terminate_instances_for_test(xml), do: parse_terminate_instances(xml)

defp parse_terminate_instances(body) do
  %{
    instances_set:
      xpath(body, ~x"//instancesSet/item"l,
        instance_id: ~x"./instanceId/text()"s,
        current_state: [
          ~x"./currentState"o,
          code: ~x"./code/text()"oi,
          name: ~x"./name/text()"os
        ],
        previous_state: [
          ~x"./previousState"o,
          code: ~x"./code/text()"oi,
          name: ~x"./name/text()"os
        ]
      )
  }
end
```

Sandbox wiring per recipe B — delegate `sandbox_terminate_instances_response(instance_ids, opts)` / stub `(_, _)` in `ec2.ex`; in `ec2/sandbox.ex`:

```elixir
def terminate_instances_response(instance_ids, opts) do
  examples = AwsSdk.Sandbox.doc_examples([:instance_ids])
  func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :terminate_instances, "*", examples)
  AwsSdk.Sandbox.apply_func(func, [instance_ids, opts], examples)
end

def set_terminate_instances_responses(tuples) do
  AwsSdk.Sandbox.set_responses(
    @registry,
    __MODULE__,
    :terminate_instances,
    AwsSdk.Sandbox.normalize_no_key(tuples)
  )
end
```

- [ ] **Step 4: Verify**

Run: `mix compile && mix test && mix format` — all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 TerminateInstances"
```

---

### Task 5: EC2 `get_console_output`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex`, `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `maybe_put/3`.
- Produces: `AwsSdk.EC2.get_console_output(instance_id :: String.t(), opts :: keyword()) :: {:ok, %{instance_id: String.t(), timestamp: String.t() | nil, output: String.t() | nil}} | {:error, term()}`; `parse_get_console_output_for_test/1`; `Sandbox.set_get_console_output_responses/1` keyed off `instance_id`.

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "GetConsoleOutput decodes the base64 output and keeps the timestamp" do
  # "boot ok\n" base64-encoded, as AWS returns it on the wire.
  xml = """
  <GetConsoleOutputResponse>
  <instanceId>i-1</instanceId>
  <timestamp>2026-08-05T12:00:00.000Z</timestamp>
  <output>Ym9vdCBvawo=</output>
  </GetConsoleOutputResponse>
  """

  parsed = AwsSdk.EC2.parse_get_console_output_for_test(xml)

  assert parsed.instance_id == "i-1"
  assert parsed.timestamp == "2026-08-05T12:00:00.000Z"
  assert parsed.output == "boot ok\n"
end

test "GetConsoleOutput yields nil output when AWS omits it" do
  xml = "<GetConsoleOutputResponse><instanceId>i-1</instanceId></GetConsoleOutputResponse>"

  parsed = AwsSdk.EC2.parse_get_console_output_for_test(xml)

  assert parsed.output == nil
end
```

Sandbox:

```elixir
describe "get_console_output/2" do
  test "keys off the instance id" do
    Sandbox.set_get_console_output_responses([
      {"i-1", fn -> {:ok, %{instance_id: "i-1", timestamp: nil, output: "boot ok\n"}} end}
    ])

    assert {:ok, %{output: "boot ok\n"}} =
             EC2.get_console_output("i-1", sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — `mix test test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs`, expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

```elixir
@doc """
Gets the console output for the specified instance.

AWS returns the output base64-encoded on the wire; this function decodes
it, since the encoding is transport detail rather than content (NEXT.md
calls this out explicitly). If the payload is somehow not valid base64 it
is returned as-is.

## Arguments

  * `instance_id` - The instance ID.

## Options

  * `:latest` - Boolean; when `true`, returns the latest output instead
    of the buffered post-boot snapshot.

## Examples

    AwsSdk.EC2.get_console_output("i-1234567890abcdef0", latest: true)
    #=> {:ok,
    #=>  %{
    #=>    instance_id: "i-1234567890abcdef0",
    #=>    timestamp: "2026-08-05T12:00:00.000Z",
    #=>    output: "[    0.000000] Linux version 6.1..."
    #=>  }}
"""
@spec get_console_output(instance_id :: String.t(), opts :: keyword()) ::
        {:ok, %{instance_id: String.t(), timestamp: String.t() | nil, output: String.t() | nil}}
        | {:error, term()}
def get_console_output(instance_id, opts \\ []) when is_binary(instance_id) do
  if sandbox?(opts) do
    sandbox_get_console_output_response(instance_id, opts)
  else
    do_get_console_output(instance_id, opts)
  end
end

defp do_get_console_output(instance_id, opts) do
  params =
    %{"InstanceId" => instance_id}
    |> maybe_put("Latest", opts[:latest])

  with {:ok, op} <- build_operation("GetConsoleOutput", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_get_console_output(body)}
  end
end

@doc false
def parse_get_console_output_for_test(xml), do: parse_get_console_output(xml)

defp parse_get_console_output(body) do
  result =
    xpath(body, ~x"//GetConsoleOutputResponse"e,
      instance_id: ~x"./instanceId/text()"s,
      timestamp: ~x"./timestamp/text()"os,
      output: ~x"./output/text()"os
    )

  %{result | output: decode_console_output(result.output)}
end

defp decode_console_output(nil), do: nil

defp decode_console_output(encoded) do
  # AWS base64-encodes the console text and may fold in whitespace.
  case Base.decode64(encoded, ignore: :whitespace) do
    {:ok, decoded} -> decoded
    :error -> encoded
  end
end
```

Sandbox wiring per recipe B, key = `instance_id`:

```elixir
def get_console_output_response(instance_id, opts) do
  examples = AwsSdk.Sandbox.doc_examples([:instance_id])
  func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :get_console_output, instance_id, examples)
  AwsSdk.Sandbox.apply_func(func, [instance_id, opts], examples)
end

def set_get_console_output_responses(tuples) do
  AwsSdk.Sandbox.set_responses(
    @registry,
    __MODULE__,
    :get_console_output,
    AwsSdk.Sandbox.normalize_no_key(tuples)
  )
end
```

Delegate `sandbox_get_console_output_response(instance_id, opts)` / stub `(_, _)` in `ec2.ex`.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 GetConsoleOutput with base64 decoding"
```

---

### Task 6: EC2 `describe_network_acls`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex` (near the other VPC describes), `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `put_member_list/3`, `put_filters/2`, `maybe_put/3`.
- Produces: `AwsSdk.EC2.describe_network_acls(opts :: keyword()) :: {:ok, %{network_acl_set: [map()], next_token: String.t() | nil}} | {:error, term()}`; `parse_describe_network_acls_for_test/1`; `Sandbox.set_describe_network_acls_responses/1` (bare `fn`s, key `"*"`).

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "DescribeNetworkAcls keeps entries, associations, and the default flag" do
  xml = """
  <DescribeNetworkAclsResponse><networkAclSet><item>
  <networkAclId>acl-1</networkAclId><vpcId>vpc-1</vpcId>
  <default>true</default><ownerId>123456789012</ownerId>
  <entrySet>
  <item><ruleNumber>100</ruleNumber><protocol>6</protocol><ruleAction>allow</ruleAction>
  <egress>false</egress><cidrBlock>0.0.0.0/0</cidrBlock>
  <portRange><from>443</from><to>443</to></portRange></item>
  <item><ruleNumber>32767</ruleNumber><protocol>-1</protocol><ruleAction>deny</ruleAction>
  <egress>false</egress><cidrBlock>0.0.0.0/0</cidrBlock></item>
  </entrySet>
  <associationSet><item>
  <networkAclAssociationId>aclassoc-1</networkAclAssociationId>
  <networkAclId>acl-1</networkAclId><subnetId>subnet-1</subnetId>
  </item></associationSet>
  <tagSet><item><key>Name</key><value>main</value></item></tagSet>
  </item></networkAclSet>
  <nextToken>tok</nextToken></DescribeNetworkAclsResponse>
  """

  parsed = AwsSdk.EC2.parse_describe_network_acls_for_test(xml)

  assert [acl] = parsed.network_acl_set
  assert acl.network_acl_id == "acl-1"
  assert acl.default == true
  assert [https, deny_all] = acl.entry_set
  assert https.rule_number == 100
  assert https.egress == false
  assert https.port_range == %{from: 443, to: 443}
  # An entry without a portRange must yield nil, not a map of empty strings.
  assert deny_all.port_range == nil
  assert [assoc] = acl.association_set
  assert assoc.subnet_id == "subnet-1"
  assert acl.tag_set == [%{key: "Name", value: "main"}]
  assert parsed.next_token == "tok"
end
```

Sandbox:

```elixir
describe "describe_network_acls/1" do
  test "returns the registered ACLs" do
    Sandbox.set_describe_network_acls_responses([
      fn -> {:ok, %{network_acl_set: [%{network_acl_id: "acl-1"}], next_token: nil}} end
    ])

    assert {:ok, %{network_acl_set: [%{network_acl_id: "acl-1"}]}} =
             EC2.describe_network_acls(sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — `mix test test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs`, expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

```elixir
@doc """
Describes network ACLs.

## Options

  * `:network_acl_ids` - List of ACL IDs, encoded as `NetworkAclId.N`.
  * `:filters` - List of `%{name:, values:}` filters (e.g.
    `%{name: "vpc-id", values: ["vpc-1"]}`).
  * `:next_token`, `:max_results` - Pagination.

## Examples

    AwsSdk.EC2.describe_network_acls(filters: [%{name: "vpc-id", values: ["vpc-0abc"]}])
    #=> {:ok,
    #=>  %{
    #=>    network_acl_set: [
    #=>      %{
    #=>        network_acl_id: "acl-0abc",
    #=>        vpc_id: "vpc-0abc",
    #=>        default: true,
    #=>        owner_id: "123456789012",
    #=>        entry_set: [
    #=>          %{
    #=>            rule_number: 100,
    #=>            protocol: "-1",
    #=>            rule_action: "allow",
    #=>            egress: false,
    #=>            cidr_block: "0.0.0.0/0",
    #=>            ipv6_cidr_block: nil,
    #=>            icmp_type_code: nil,
    #=>            port_range: nil
    #=>          }
    #=>        ],
    #=>        association_set: [
    #=>          %{
    #=>            network_acl_association_id: "aclassoc-1",
    #=>            network_acl_id: "acl-0abc",
    #=>            subnet_id: "subnet-1"
    #=>          }
    #=>        ],
    #=>        tag_set: []
    #=>      }
    #=>    ],
    #=>    next_token: nil
    #=>  }}
"""
@spec describe_network_acls(opts :: keyword()) ::
        {:ok, %{network_acl_set: list(map()), next_token: String.t() | nil}} | {:error, term()}
def describe_network_acls(opts \\ []) do
  if sandbox?(opts) do
    sandbox_describe_network_acls_response(opts)
  else
    do_describe_network_acls(opts)
  end
end

defp do_describe_network_acls(opts) do
  params =
    %{}
    |> put_member_list("NetworkAclId", opts[:network_acl_ids] || [])
    |> put_filters(opts[:filters] || [])
    |> maybe_put("NextToken", opts[:next_token])
    |> maybe_put("MaxResults", opts[:max_results])

  with {:ok, op} <- build_operation("DescribeNetworkAcls", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_describe_network_acls(body)}
  end
end

@doc false
def parse_describe_network_acls_for_test(xml), do: parse_describe_network_acls(xml)

defp parse_describe_network_acls(body) do
  acls =
    xpath(body, ~x"//networkAclSet/item"l,
      network_acl_id: ~x"./networkAclId/text()"s,
      vpc_id: ~x"./vpcId/text()"os,
      default: ~x"./default/text()"s,
      owner_id: ~x"./ownerId/text()"os,
      entry_set: [
        ~x"./entrySet/item"l,
        rule_number: ~x"./ruleNumber/text()"oi,
        # protocol is "-1" or an IANA number; AWS types it as a string.
        protocol: ~x"./protocol/text()"os,
        rule_action: ~x"./ruleAction/text()"os,
        egress: ~x"./egress/text()"s,
        cidr_block: ~x"./cidrBlock/text()"os,
        ipv6_cidr_block: ~x"./ipv6CidrBlock/text()"os,
        icmp_type_code: [
          ~x"./icmpTypeCode"o,
          code: ~x"./code/text()"oi,
          type: ~x"./type/text()"oi
        ],
        port_range: [~x"./portRange"o, from: ~x"./from/text()"oi, to: ~x"./to/text()"oi]
      ],
      association_set: [
        ~x"./associationSet/item"l,
        network_acl_association_id: ~x"./networkAclAssociationId/text()"s,
        network_acl_id: ~x"./networkAclId/text()"os,
        subnet_id: ~x"./subnetId/text()"os
      ],
      tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
    )

  %{
    network_acl_set: Enum.map(acls, &coerce_network_acl/1),
    next_token: xpath(body, ~x"//DescribeNetworkAclsResponse/nextToken/text()"os)
  }
end

defp coerce_network_acl(%{default: default, entry_set: entries} = acl) do
  %{acl | default: default === "true", entry_set: Enum.map(entries, &coerce_network_acl_entry/1)}
end

defp coerce_network_acl_entry(%{egress: egress} = entry) do
  %{entry | egress: egress === "true"}
end
```

(The `coerce_*` defps mirror the module's existing `coerce_is_default/1` used by `describe_vpcs` — same naming, same `%{item | field: value === "true"}` body.)

Sandbox wiring per recipe B, arity 1, key `"*"` (mirror `describe_launch_templates_response/1` in `ec2/sandbox.ex` with op name `:describe_network_acls`); delegate `sandbox_describe_network_acls_response(opts)` / stub `(_)` in `ec2.ex`.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 DescribeNetworkAcls"
```

---

### Task 7: EC2 `describe_route_tables`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex`, `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: same EC2 helpers as Task 6.
- Produces: `AwsSdk.EC2.describe_route_tables(opts :: keyword()) :: {:ok, %{route_table_set: [map()], next_token: String.t() | nil}} | {:error, term()}`; `parse_describe_route_tables_for_test/1`; `Sandbox.set_describe_route_tables_responses/1` (bare `fn`s, key `"*"`).

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "DescribeRouteTables keeps routes, associations, and propagating VGWs" do
  xml = """
  <DescribeRouteTablesResponse><routeTableSet><item>
  <routeTableId>rtb-1</routeTableId><vpcId>vpc-1</vpcId><ownerId>123456789012</ownerId>
  <routeSet>
  <item><destinationCidrBlock>10.0.0.0/16</destinationCidrBlock>
  <gatewayId>local</gatewayId><state>active</state><origin>CreateRouteTable</origin></item>
  <item><destinationCidrBlock>0.0.0.0/0</destinationCidrBlock>
  <natGatewayId>nat-1</natGatewayId><state>blackhole</state><origin>CreateRoute</origin></item>
  </routeSet>
  <associationSet><item>
  <routeTableAssociationId>rtbassoc-1</routeTableAssociationId>
  <routeTableId>rtb-1</routeTableId><subnetId>subnet-1</subnetId><main>false</main>
  <associationState><state>associated</state></associationState>
  </item></associationSet>
  <propagatingVgwSet><item><gatewayId>vgw-1</gatewayId></item></propagatingVgwSet>
  <tagSet><item><key>Name</key><value>private</value></item></tagSet>
  </item></routeTableSet></DescribeRouteTablesResponse>
  """

  parsed = AwsSdk.EC2.parse_describe_route_tables_for_test(xml)

  assert [table] = parsed.route_table_set
  assert table.route_table_id == "rtb-1"
  assert [local, nat] = table.route_set
  assert local.gateway_id == "local"
  assert nat.nat_gateway_id == "nat-1"
  assert nat.state == "blackhole"
  assert [assoc] = table.association_set
  assert assoc.main == false
  assert assoc.association_state == %{state: "associated", status_message: nil}
  assert table.propagating_vgw_set == [%{gateway_id: "vgw-1"}]
  assert parsed.next_token == nil
end
```

Sandbox:

```elixir
describe "describe_route_tables/1" do
  test "returns the registered route tables" do
    Sandbox.set_describe_route_tables_responses([
      fn -> {:ok, %{route_table_set: [%{route_table_id: "rtb-1"}], next_token: nil}} end
    ])

    assert {:ok, %{route_table_set: [%{route_table_id: "rtb-1"}]}} =
             EC2.describe_route_tables(sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

```elixir
@doc """
Describes route tables.

## Options

  * `:route_table_ids` - List of route table IDs, encoded as `RouteTableId.N`.
  * `:filters` - List of `%{name:, values:}` filters.
  * `:next_token`, `:max_results` - Pagination.

## Examples

    AwsSdk.EC2.describe_route_tables(filters: [%{name: "vpc-id", values: ["vpc-0abc"]}])
    #=> {:ok,
    #=>  %{
    #=>    route_table_set: [
    #=>      %{
    #=>        route_table_id: "rtb-0abc",
    #=>        vpc_id: "vpc-0abc",
    #=>        owner_id: "123456789012",
    #=>        route_set: [
    #=>          %{
    #=>            destination_cidr_block: "0.0.0.0/0",
    #=>            gateway_id: "igw-0abc",
    #=>            state: "active",
    #=>            origin: "CreateRoute",
    #=>            nat_gateway_id: nil,
    #=>            ...
    #=>          }
    #=>        ],
    #=>        association_set: [
    #=>          %{
    #=>            route_table_association_id: "rtbassoc-1",
    #=>            route_table_id: "rtb-0abc",
    #=>            subnet_id: "subnet-1",
    #=>            gateway_id: nil,
    #=>            main: false,
    #=>            association_state: %{state: "associated", status_message: nil}
    #=>          }
    #=>        ],
    #=>        propagating_vgw_set: [],
    #=>        tag_set: []
    #=>      }
    #=>    ],
    #=>    next_token: nil
    #=>  }}
"""
@spec describe_route_tables(opts :: keyword()) ::
        {:ok, %{route_table_set: list(map()), next_token: String.t() | nil}} | {:error, term()}
def describe_route_tables(opts \\ []) do
  if sandbox?(opts) do
    sandbox_describe_route_tables_response(opts)
  else
    do_describe_route_tables(opts)
  end
end

defp do_describe_route_tables(opts) do
  params =
    %{}
    |> put_member_list("RouteTableId", opts[:route_table_ids] || [])
    |> put_filters(opts[:filters] || [])
    |> maybe_put("NextToken", opts[:next_token])
    |> maybe_put("MaxResults", opts[:max_results])

  with {:ok, op} <- build_operation("DescribeRouteTables", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_describe_route_tables(body)}
  end
end

@doc false
def parse_describe_route_tables_for_test(xml), do: parse_describe_route_tables(xml)

defp parse_describe_route_tables(body) do
  tables =
    xpath(body, ~x"//routeTableSet/item"l,
      route_table_id: ~x"./routeTableId/text()"s,
      vpc_id: ~x"./vpcId/text()"os,
      owner_id: ~x"./ownerId/text()"os,
      route_set: [
        ~x"./routeSet/item"l,
        destination_cidr_block: ~x"./destinationCidrBlock/text()"os,
        destination_ipv6_cidr_block: ~x"./destinationIpv6CidrBlock/text()"os,
        destination_prefix_list_id: ~x"./destinationPrefixListId/text()"os,
        egress_only_internet_gateway_id: ~x"./egressOnlyInternetGatewayId/text()"os,
        gateway_id: ~x"./gatewayId/text()"os,
        instance_id: ~x"./instanceId/text()"os,
        instance_owner_id: ~x"./instanceOwnerId/text()"os,
        nat_gateway_id: ~x"./natGatewayId/text()"os,
        transit_gateway_id: ~x"./transitGatewayId/text()"os,
        local_gateway_id: ~x"./localGatewayId/text()"os,
        carrier_gateway_id: ~x"./carrierGatewayId/text()"os,
        network_interface_id: ~x"./networkInterfaceId/text()"os,
        vpc_peering_connection_id: ~x"./vpcPeeringConnectionId/text()"os,
        core_network_arn: ~x"./coreNetworkArn/text()"os,
        state: ~x"./state/text()"os,
        origin: ~x"./origin/text()"os
      ],
      association_set: [
        ~x"./associationSet/item"l,
        route_table_association_id: ~x"./routeTableAssociationId/text()"s,
        route_table_id: ~x"./routeTableId/text()"os,
        subnet_id: ~x"./subnetId/text()"os,
        gateway_id: ~x"./gatewayId/text()"os,
        main: ~x"./main/text()"s,
        association_state: [
          ~x"./associationState"o,
          state: ~x"./state/text()"os,
          status_message: ~x"./statusMessage/text()"os
        ]
      ],
      propagating_vgw_set: [~x"./propagatingVgwSet/item"l, gateway_id: ~x"./gatewayId/text()"s],
      tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
    )

  %{
    route_table_set: Enum.map(tables, &coerce_route_table/1),
    next_token: xpath(body, ~x"//DescribeRouteTablesResponse/nextToken/text()"os)
  }
end

defp coerce_route_table(%{association_set: assocs} = table) do
  %{table | association_set: Enum.map(assocs, &coerce_route_table_association/1)}
end

defp coerce_route_table_association(%{main: main} = assoc) do
  %{assoc | main: main === "true"}
end
```

Sandbox wiring per recipe B, arity 1, key `"*"`; delegate `sandbox_describe_route_tables_response(opts)` / stub `(_)`.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 DescribeRouteTables"
```

---

### Task 8: EC2 `describe_key_pairs` + `delete_key_pair`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex` (new "Key pairs" section), `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `put_member_list/3`, `put_filters/2`, `maybe_put/3` in `ec2.ex`.
- Produces: `AwsSdk.EC2.describe_key_pairs(opts) :: {:ok, %{key_set: [map()]}} | {:error, term()}`; `AwsSdk.EC2.delete_key_pair(key_name :: String.t(), opts) :: {:ok, %{return: boolean(), key_pair_id: String.t() | nil}} | {:error, term()}`; `parse_describe_key_pairs_for_test/1`, `parse_delete_key_pair_for_test/1`; `Sandbox.set_describe_key_pairs_responses/1` (key `"*"`), `Sandbox.set_delete_key_pair_responses/1` (keyed off `key_name`).

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "DescribeKeyPairs keeps fingerprint, type, and tags" do
  xml = """
  <DescribeKeyPairsResponse><keySet><item>
  <keyPairId>key-1</keyPairId><keyName>deploy</keyName>
  <keyFingerprint>ab:cd</keyFingerprint><keyType>ed25519</keyType>
  <createTime>2026-01-01T00:00:00Z</createTime>
  <tagSet><item><key>Team</key><value>ops</value></item></tagSet>
  </item></keySet></DescribeKeyPairsResponse>
  """

  parsed = AwsSdk.EC2.parse_describe_key_pairs_for_test(xml)

  assert [key] = parsed.key_set
  assert key.key_pair_id == "key-1"
  assert key.key_name == "deploy"
  assert key.key_fingerprint == "ab:cd"
  assert key.key_type == "ed25519"
  assert key.create_time == "2026-01-01T00:00:00Z"
  assert key.tag_set == [%{key: "Team", value: "ops"}]
end

test "DeleteKeyPair keeps the return flag and the deleted key's id" do
  xml = """
  <DeleteKeyPairResponse><return>true</return><keyPairId>key-1</keyPairId></DeleteKeyPairResponse>
  """

  parsed = AwsSdk.EC2.parse_delete_key_pair_for_test(xml)

  assert parsed.return == true
  assert parsed.key_pair_id == "key-1"
end
```

Sandbox:

```elixir
describe "describe_key_pairs/1" do
  test "returns the registered key pairs" do
    Sandbox.set_describe_key_pairs_responses([
      fn -> {:ok, %{key_set: [%{key_name: "deploy"}]}} end
    ])

    assert {:ok, %{key_set: [%{key_name: "deploy"}]}} =
             EC2.describe_key_pairs(sandbox: [enabled: true])
  end
end

describe "delete_key_pair/2" do
  test "keys off the key name" do
    Sandbox.set_delete_key_pair_responses([
      {"deploy", fn -> {:ok, %{return: true, key_pair_id: "key-1"}} end}
    ])

    assert {:ok, %{return: true}} = EC2.delete_key_pair("deploy", sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

```elixir
@doc """
Describes key pairs.

## Options

  * `:key_names` - List of key names, encoded as `KeyName.N`.
  * `:key_pair_ids` - List of key pair IDs, encoded as `KeyPairId.N`.
  * `:filters` - List of `%{name:, values:}` filters.
  * `:include_public_key` - Boolean; include the public key material.

## Examples

    AwsSdk.EC2.describe_key_pairs(filters: [%{name: "key-name", values: ["deploy"]}])
    #=> {:ok,
    #=>  %{
    #=>    key_set: [
    #=>      %{
    #=>        key_pair_id: "key-0abc",
    #=>        key_name: "deploy",
    #=>        key_fingerprint: "ab:cd:...",
    #=>        key_type: "ed25519",
    #=>        create_time: "2026-01-01T00:00:00Z",
    #=>        public_key: nil,
    #=>        tag_set: []
    #=>      }
    #=>    ]
    #=>  }}
"""
@spec describe_key_pairs(opts :: keyword()) ::
        {:ok, %{key_set: list(map())}} | {:error, term()}
def describe_key_pairs(opts \\ []) do
  if sandbox?(opts) do
    sandbox_describe_key_pairs_response(opts)
  else
    do_describe_key_pairs(opts)
  end
end

defp do_describe_key_pairs(opts) do
  params =
    %{}
    |> put_member_list("KeyName", opts[:key_names] || [])
    |> put_member_list("KeyPairId", opts[:key_pair_ids] || [])
    |> put_filters(opts[:filters] || [])
    |> maybe_put("IncludePublicKey", opts[:include_public_key])

  with {:ok, op} <- build_operation("DescribeKeyPairs", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_describe_key_pairs(body)}
  end
end

@doc false
def parse_describe_key_pairs_for_test(xml), do: parse_describe_key_pairs(xml)

defp parse_describe_key_pairs(body) do
  %{
    key_set:
      xpath(body, ~x"//keySet/item"l,
        key_pair_id: ~x"./keyPairId/text()"os,
        key_name: ~x"./keyName/text()"s,
        key_fingerprint: ~x"./keyFingerprint/text()"os,
        key_type: ~x"./keyType/text()"os,
        create_time: ~x"./createTime/text()"os,
        public_key: ~x"./publicKey/text()"os,
        tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
      )
  }
end

@doc """
Deletes the specified key pair by name.

## Examples

    AwsSdk.EC2.delete_key_pair("deploy")
    #=> {:ok, %{return: true, key_pair_id: "key-0abc"}}
"""
@spec delete_key_pair(key_name :: String.t(), opts :: keyword()) ::
        {:ok, %{return: boolean(), key_pair_id: String.t() | nil}} | {:error, term()}
def delete_key_pair(key_name, opts \\ []) when is_binary(key_name) do
  if sandbox?(opts) do
    sandbox_delete_key_pair_response(key_name, opts)
  else
    do_delete_key_pair(key_name, opts)
  end
end

defp do_delete_key_pair(key_name, opts) do
  with {:ok, op} <- build_operation("DeleteKeyPair", %{"KeyName" => key_name}, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_delete_key_pair(body)}
  end
end

@doc false
def parse_delete_key_pair_for_test(xml), do: parse_delete_key_pair(xml)

defp parse_delete_key_pair(body) do
  %{
    return: xpath(body, ~x"//DeleteKeyPairResponse/return/text()"os) == "true",
    key_pair_id: xpath(body, ~x"//DeleteKeyPairResponse/keyPairId/text()"os)
  }
end
```

Sandbox wiring per recipe B: `describe_key_pairs` pair at arity 1 key `"*"`; `delete_key_pair` pair at arity 2 keyed off `key_name` (mirror `delete_snapshot_response`); delegates `sandbox_describe_key_pairs_response(opts)` and `sandbox_delete_key_pair_response(key_name, opts)` with stubs `(_)` / `(_, _)`.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 DescribeKeyPairs and DeleteKeyPair"
```

---

### Task 9: EC2 `describe_security_group_rules`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex` (next to the other security-group functions), `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `put_member_list/3`, `put_filters/2`, `maybe_put/3`.
- Produces: `AwsSdk.EC2.describe_security_group_rules(opts) :: {:ok, %{security_group_rule_set: [map()], next_token: String.t() | nil}} | {:error, term()}`; `parse_describe_security_group_rules_for_test/1`; `Sandbox.set_describe_security_group_rules_responses/1` (key `"*"`).

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "DescribeSecurityGroupRules keeps rule granularity and referenced groups" do
  xml = """
  <DescribeSecurityGroupRulesResponse><securityGroupRuleSet>
  <item><securityGroupRuleId>sgr-1</securityGroupRuleId>
  <groupId>sg-1</groupId><groupOwnerId>123456789012</groupOwnerId>
  <isEgress>false</isEgress><ipProtocol>tcp</ipProtocol>
  <fromPort>443</fromPort><toPort>443</toPort>
  <cidrIpv4>0.0.0.0/0</cidrIpv4>
  <tagSet/></item>
  <item><securityGroupRuleId>sgr-2</securityGroupRuleId>
  <groupId>sg-1</groupId><isEgress>true</isEgress><ipProtocol>-1</ipProtocol>
  <fromPort>-1</fromPort><toPort>-1</toPort>
  <referencedGroupInfo><groupId>sg-2</groupId><userId>123456789012</userId></referencedGroupInfo>
  </item>
  </securityGroupRuleSet>
  <nextToken>tok</nextToken></DescribeSecurityGroupRulesResponse>
  """

  parsed = AwsSdk.EC2.parse_describe_security_group_rules_for_test(xml)

  assert [ingress, egress] = parsed.security_group_rule_set
  assert ingress.security_group_rule_id == "sgr-1"
  assert ingress.is_egress == false
  assert ingress.from_port == 443
  assert ingress.cidr_ipv4 == "0.0.0.0/0"
  assert ingress.referenced_group_info == nil
  assert egress.is_egress == true
  assert egress.referenced_group_info.group_id == "sg-2"
  assert parsed.next_token == "tok"
end
```

Sandbox:

```elixir
describe "describe_security_group_rules/1" do
  test "returns the registered rules" do
    Sandbox.set_describe_security_group_rules_responses([
      fn ->
        {:ok, %{security_group_rule_set: [%{security_group_rule_id: "sgr-1"}], next_token: nil}}
      end
    ])

    assert {:ok, %{security_group_rule_set: [%{security_group_rule_id: "sgr-1"}]}} =
             EC2.describe_security_group_rules(sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

```elixir
@doc """
Describes security group rules — the rule-granular read
(`aws_vpc_security_group_ingress_rule` granularity, one entry per rule
with its own `security_group_rule_id`).

## Options

  * `:security_group_rule_ids` - List of rule IDs, encoded as
    `SecurityGroupRuleId.N`.
  * `:filters` - List of `%{name:, values:}` filters (e.g.
    `%{name: "group-id", values: ["sg-1"]}`).
  * `:next_token`, `:max_results` - Pagination.

## Examples

    AwsSdk.EC2.describe_security_group_rules(
      filters: [%{name: "group-id", values: ["sg-0abc"]}]
    )
    #=> {:ok,
    #=>  %{
    #=>    security_group_rule_set: [
    #=>      %{
    #=>        security_group_rule_id: "sgr-0abc",
    #=>        group_id: "sg-0abc",
    #=>        group_owner_id: "123456789012",
    #=>        is_egress: false,
    #=>        ip_protocol: "tcp",
    #=>        from_port: 443,
    #=>        to_port: 443,
    #=>        cidr_ipv4: "0.0.0.0/0",
    #=>        cidr_ipv6: nil,
    #=>        prefix_list_id: nil,
    #=>        referenced_group_info: nil,
    #=>        description: nil,
    #=>        tag_set: []
    #=>      }
    #=>    ],
    #=>    next_token: nil
    #=>  }}
"""
@spec describe_security_group_rules(opts :: keyword()) ::
        {:ok, %{security_group_rule_set: list(map()), next_token: String.t() | nil}}
        | {:error, term()}
def describe_security_group_rules(opts \\ []) do
  if sandbox?(opts) do
    sandbox_describe_security_group_rules_response(opts)
  else
    do_describe_security_group_rules(opts)
  end
end

defp do_describe_security_group_rules(opts) do
  params =
    %{}
    |> put_member_list("SecurityGroupRuleId", opts[:security_group_rule_ids] || [])
    |> put_filters(opts[:filters] || [])
    |> maybe_put("NextToken", opts[:next_token])
    |> maybe_put("MaxResults", opts[:max_results])

  with {:ok, op} <- build_operation("DescribeSecurityGroupRules", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_describe_security_group_rules(body)}
  end
end

@doc false
def parse_describe_security_group_rules_for_test(xml),
  do: parse_describe_security_group_rules(xml)

defp parse_describe_security_group_rules(body) do
  rules =
    xpath(body, ~x"//securityGroupRuleSet/item"l,
      security_group_rule_id: ~x"./securityGroupRuleId/text()"s,
      group_id: ~x"./groupId/text()"os,
      group_owner_id: ~x"./groupOwnerId/text()"os,
      is_egress: ~x"./isEgress/text()"s,
      ip_protocol: ~x"./ipProtocol/text()"os,
      from_port: ~x"./fromPort/text()"oi,
      to_port: ~x"./toPort/text()"oi,
      cidr_ipv4: ~x"./cidrIpv4/text()"os,
      cidr_ipv6: ~x"./cidrIpv6/text()"os,
      prefix_list_id: ~x"./prefixListId/text()"os,
      referenced_group_info: [
        ~x"./referencedGroupInfo"o,
        group_id: ~x"./groupId/text()"os,
        peering_status: ~x"./peeringStatus/text()"os,
        user_id: ~x"./userId/text()"os,
        vpc_id: ~x"./vpcId/text()"os,
        vpc_peering_connection_id: ~x"./vpcPeeringConnectionId/text()"os
      ],
      description: ~x"./description/text()"os,
      security_group_rule_arn: ~x"./securityGroupRuleArn/text()"os,
      tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
    )

  %{
    security_group_rule_set: Enum.map(rules, &coerce_is_egress/1),
    next_token: xpath(body, ~x"//DescribeSecurityGroupRulesResponse/nextToken/text()"os)
  }
end

defp coerce_is_egress(%{is_egress: value} = rule) do
  %{rule | is_egress: value === "true"}
end
```

Sandbox wiring per recipe B, arity 1, key `"*"`; delegate `sandbox_describe_security_group_rules_response(opts)` / stub `(_)`.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 DescribeSecurityGroupRules"
```

---

### Task 10: EC2 `describe_snapshots`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex` (next to `delete_snapshot`), `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `put_member_list/3`, `put_filters/2`, `maybe_put/3`.
- Produces: `AwsSdk.EC2.describe_snapshots(opts) :: {:ok, %{snapshot_set: [map()], next_token: String.t() | nil}} | {:error, term()}`; `parse_describe_snapshots_for_test/1`; `Sandbox.set_describe_snapshots_responses/1` (key `"*"`).

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "DescribeSnapshots keeps the full snapshot shape" do
  xml = """
  <DescribeSnapshotsResponse><snapshotSet><item>
  <snapshotId>snap-1</snapshotId><volumeId>vol-1</volumeId>
  <status>completed</status><startTime>2026-01-01T00:00:00Z</startTime>
  <progress>100%</progress><ownerId>123456789012</ownerId>
  <volumeSize>30</volumeSize><description>ami backing</description>
  <encrypted>false</encrypted><storageTier>standard</storageTier>
  <tagSet><item><key>Name</key><value>web</value></item></tagSet>
  </item></snapshotSet>
  <nextToken>tok</nextToken></DescribeSnapshotsResponse>
  """

  parsed = AwsSdk.EC2.parse_describe_snapshots_for_test(xml)

  assert [snap] = parsed.snapshot_set
  assert snap.snapshot_id == "snap-1"
  assert snap.volume_id == "vol-1"
  assert snap.status == "completed"
  assert snap.start_time == "2026-01-01T00:00:00Z"
  assert snap.volume_size == 30
  assert snap.encrypted == false
  assert snap.tag_set == [%{key: "Name", value: "web"}]
  assert parsed.next_token == "tok"
end
```

Sandbox:

```elixir
describe "describe_snapshots/1" do
  test "returns the registered snapshots" do
    Sandbox.set_describe_snapshots_responses([
      fn -> {:ok, %{snapshot_set: [%{snapshot_id: "snap-1"}], next_token: nil}} end
    ])

    assert {:ok, %{snapshot_set: [%{snapshot_id: "snap-1"}]}} =
             EC2.describe_snapshots(owner_ids: ["self"], sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

```elixir
@doc """
Describes EBS snapshots.

Without `:owner_ids`, `:restorable_by_user_ids`, or `:snapshot_ids`, AWS
returns all snapshots you can access, including public ones — pass
`owner_ids: ["self"]` for just your own.

## Options

  * `:snapshot_ids` - List of snapshot IDs, encoded as `SnapshotId.N`.
  * `:owner_ids` - List of owner IDs (or `"self"`/`"amazon"`), encoded as `Owner.N`.
  * `:restorable_by_user_ids` - List of account IDs, encoded as `RestorableBy.N`.
  * `:filters` - List of `%{name:, values:}` filters.
  * `:next_token`, `:max_results` - Pagination.

## Examples

    AwsSdk.EC2.describe_snapshots(owner_ids: ["self"])
    #=> {:ok,
    #=>  %{
    #=>    snapshot_set: [
    #=>      %{
    #=>        snapshot_id: "snap-0abc",
    #=>        volume_id: "vol-0abc",
    #=>        status: "completed",
    #=>        status_message: nil,
    #=>        start_time: "2026-01-01T00:00:00Z",
    #=>        progress: "100%",
    #=>        owner_id: "123456789012",
    #=>        owner_alias: nil,
    #=>        volume_size: 30,
    #=>        description: "",
    #=>        encrypted: false,
    #=>        kms_key_id: nil,
    #=>        outpost_arn: nil,
    #=>        storage_tier: "standard",
    #=>        restore_expiry_time: nil,
    #=>        tag_set: []
    #=>      }
    #=>    ],
    #=>    next_token: nil
    #=>  }}
"""
@spec describe_snapshots(opts :: keyword()) ::
        {:ok, %{snapshot_set: list(map()), next_token: String.t() | nil}} | {:error, term()}
def describe_snapshots(opts \\ []) do
  if sandbox?(opts) do
    sandbox_describe_snapshots_response(opts)
  else
    do_describe_snapshots(opts)
  end
end

defp do_describe_snapshots(opts) do
  params =
    %{}
    |> put_member_list("SnapshotId", opts[:snapshot_ids] || [])
    |> put_member_list("Owner", opts[:owner_ids] || [])
    |> put_member_list("RestorableBy", opts[:restorable_by_user_ids] || [])
    |> put_filters(opts[:filters] || [])
    |> maybe_put("NextToken", opts[:next_token])
    |> maybe_put("MaxResults", opts[:max_results])

  with {:ok, op} <- build_operation("DescribeSnapshots", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_describe_snapshots(body)}
  end
end

@doc false
def parse_describe_snapshots_for_test(xml), do: parse_describe_snapshots(xml)

defp parse_describe_snapshots(body) do
  snapshots =
    xpath(body, ~x"//snapshotSet/item"l,
      snapshot_id: ~x"./snapshotId/text()"s,
      volume_id: ~x"./volumeId/text()"os,
      status: ~x"./status/text()"os,
      status_message: ~x"./statusMessage/text()"os,
      start_time: ~x"./startTime/text()"os,
      progress: ~x"./progress/text()"os,
      owner_id: ~x"./ownerId/text()"os,
      owner_alias: ~x"./ownerAlias/text()"os,
      volume_size: ~x"./volumeSize/text()"oi,
      description: ~x"./description/text()"os,
      encrypted: ~x"./encrypted/text()"s,
      kms_key_id: ~x"./kmsKeyId/text()"os,
      data_encryption_key_id: ~x"./dataEncryptionKeyId/text()"os,
      outpost_arn: ~x"./outpostArn/text()"os,
      storage_tier: ~x"./storageTier/text()"os,
      restore_expiry_time: ~x"./restoreExpiryTime/text()"os,
      sse_type: ~x"./sseType/text()"os,
      availability_zone: ~x"./availabilityZone/text()"os,
      transfer_type: ~x"./transferType/text()"os,
      completion_duration_minutes: ~x"./completionDurationMinutes/text()"oi,
      completion_time: ~x"./completionTime/text()"os,
      full_snapshot_size_in_bytes: ~x"./fullSnapshotSizeInBytes/text()"oi,
      tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
    )

  %{
    snapshot_set: Enum.map(snapshots, &coerce_encrypted/1),
    next_token: xpath(body, ~x"//DescribeSnapshotsResponse/nextToken/text()"os)
  }
end

defp coerce_encrypted(%{encrypted: value} = snapshot) do
  %{snapshot | encrypted: value === "true"}
end
```

Sandbox wiring per recipe B, arity 1, key `"*"`; delegate `sandbox_describe_snapshots_response(opts)` / stub `(_)`.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 DescribeSnapshots"
```

---

### Task 11: EC2 `describe_network_interfaces`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex`, `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `put_member_list/3`, `put_filters/2`, `maybe_put/3`.
- Produces: `AwsSdk.EC2.describe_network_interfaces(opts) :: {:ok, %{network_interface_set: [map()], next_token: String.t() | nil}} | {:error, term()}`; `parse_describe_network_interfaces_for_test/1`; `Sandbox.set_describe_network_interfaces_responses/1` (key `"*"`).

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "DescribeNetworkInterfaces keeps attachment, association, and groups" do
  xml = """
  <DescribeNetworkInterfacesResponse><networkInterfaceSet><item>
  <networkInterfaceId>eni-1</networkInterfaceId><subnetId>subnet-1</subnetId>
  <vpcId>vpc-1</vpcId><availabilityZone>us-east-1a</availabilityZone>
  <description>web eni</description><ownerId>123456789012</ownerId>
  <status>in-use</status><macAddress>0a:bb</macAddress>
  <privateIpAddress>10.0.1.5</privateIpAddress>
  <privateDnsName>ip-10-0-1-5.ec2.internal</privateDnsName>
  <sourceDestCheck>true</sourceDestCheck><interfaceType>interface</interfaceType>
  <requesterManaged>false</requesterManaged>
  <groupSet><item><groupId>sg-1</groupId><groupName>web</groupName></item></groupSet>
  <attachment><attachmentId>eni-attach-1</attachmentId><instanceId>i-1</instanceId>
  <instanceOwnerId>123456789012</instanceOwnerId><deviceIndex>0</deviceIndex>
  <status>attached</status><attachTime>2026-01-01T00:00:00Z</attachTime>
  <deleteOnTermination>true</deleteOnTermination></attachment>
  <association><publicIp>3.3.3.3</publicIp><publicDnsName>ec2-3-3-3-3.compute-1.amazonaws.com</publicDnsName>
  <ipOwnerId>amazon</ipOwnerId></association>
  <privateIpAddressesSet><item><privateIpAddress>10.0.1.5</privateIpAddress>
  <primary>true</primary></item></privateIpAddressesSet>
  <tagSet/>
  </item></networkInterfaceSet></DescribeNetworkInterfacesResponse>
  """

  parsed = AwsSdk.EC2.parse_describe_network_interfaces_for_test(xml)

  assert [eni] = parsed.network_interface_set
  assert eni.network_interface_id == "eni-1"
  assert eni.status == "in-use"
  assert eni.group_set == [%{group_id: "sg-1", group_name: "web"}]
  assert eni.attachment.instance_id == "i-1"
  assert eni.attachment.device_index == 0
  assert eni.association.public_ip == "3.3.3.3"
  assert [primary_ip] = eni.private_ip_addresses_set
  assert primary_ip.primary == "true"
  assert parsed.next_token == nil
end

test "DescribeNetworkInterfaces yields nil for a detached interface's attachment" do
  xml = """
  <DescribeNetworkInterfacesResponse><networkInterfaceSet><item>
  <networkInterfaceId>eni-2</networkInterfaceId><status>available</status>
  </item></networkInterfaceSet></DescribeNetworkInterfacesResponse>
  """

  parsed = AwsSdk.EC2.parse_describe_network_interfaces_for_test(xml)

  assert [eni] = parsed.network_interface_set
  assert eni.attachment == nil
  assert eni.association == nil
end
```

Sandbox:

```elixir
describe "describe_network_interfaces/1" do
  test "returns the registered interfaces" do
    Sandbox.set_describe_network_interfaces_responses([
      fn ->
        {:ok, %{network_interface_set: [%{network_interface_id: "eni-1"}], next_token: nil}}
      end
    ])

    assert {:ok, %{network_interface_set: [%{network_interface_id: "eni-1"}]}} =
             EC2.describe_network_interfaces(sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

```elixir
@doc """
Describes network interfaces. The deployd use is answering "is this
security group attached to anything" via the `group-id` filter.

## Options

  * `:network_interface_ids` - List of ENI IDs, encoded as `NetworkInterfaceId.N`.
  * `:filters` - List of `%{name:, values:}` filters (e.g.
    `%{name: "group-id", values: ["sg-1"]}`).
  * `:next_token`, `:max_results` - Pagination.

## Examples

    AwsSdk.EC2.describe_network_interfaces(filters: [%{name: "group-id", values: ["sg-0abc"]}])
    #=> {:ok,
    #=>  %{
    #=>    network_interface_set: [
    #=>      %{
    #=>        network_interface_id: "eni-0abc",
    #=>        subnet_id: "subnet-1",
    #=>        vpc_id: "vpc-1",
    #=>        availability_zone: "us-east-1a",
    #=>        description: "",
    #=>        owner_id: "123456789012",
    #=>        requester_id: nil,
    #=>        requester_managed: false,
    #=>        status: "in-use",
    #=>        mac_address: "0a:bb:cc:dd:ee:ff",
    #=>        private_ip_address: "10.0.1.5",
    #=>        private_dns_name: "ip-10-0-1-5.ec2.internal",
    #=>        source_dest_check: true,
    #=>        interface_type: "interface",
    #=>        group_set: [%{group_id: "sg-0abc", group_name: "web"}],
    #=>        attachment: %{
    #=>          attachment_id: "eni-attach-1",
    #=>          instance_id: "i-1",
    #=>          instance_owner_id: "123456789012",
    #=>          device_index: 0,
    #=>          status: "attached",
    #=>          attach_time: "2026-01-01T00:00:00Z",
    #=>          delete_on_termination: "true"
    #=>        },
    #=>        association: nil,
    #=>        private_ip_addresses_set: [
    #=>          %{private_ip_address: "10.0.1.5", private_dns_name: nil, primary: "true", association: nil}
    #=>        ],
    #=>        ipv6_addresses_set: [],
    #=>        tag_set: []
    #=>      }
    #=>    ],
    #=>    next_token: nil
    #=>  }}
"""
@spec describe_network_interfaces(opts :: keyword()) ::
        {:ok, %{network_interface_set: list(map()), next_token: String.t() | nil}}
        | {:error, term()}
def describe_network_interfaces(opts \\ []) do
  if sandbox?(opts) do
    sandbox_describe_network_interfaces_response(opts)
  else
    do_describe_network_interfaces(opts)
  end
end

defp do_describe_network_interfaces(opts) do
  params =
    %{}
    |> put_member_list("NetworkInterfaceId", opts[:network_interface_ids] || [])
    |> put_filters(opts[:filters] || [])
    |> maybe_put("NextToken", opts[:next_token])
    |> maybe_put("MaxResults", opts[:max_results])

  with {:ok, op} <- build_operation("DescribeNetworkInterfaces", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_describe_network_interfaces(body)}
  end
end

@doc false
def parse_describe_network_interfaces_for_test(xml), do: parse_describe_network_interfaces(xml)

defp parse_describe_network_interfaces(body) do
  enis =
    xpath(body, ~x"//networkInterfaceSet/item"l,
      network_interface_id: ~x"./networkInterfaceId/text()"s,
      subnet_id: ~x"./subnetId/text()"os,
      vpc_id: ~x"./vpcId/text()"os,
      availability_zone: ~x"./availabilityZone/text()"os,
      description: ~x"./description/text()"os,
      owner_id: ~x"./ownerId/text()"os,
      requester_id: ~x"./requesterId/text()"os,
      requester_managed: ~x"./requesterManaged/text()"s,
      status: ~x"./status/text()"os,
      mac_address: ~x"./macAddress/text()"os,
      private_ip_address: ~x"./privateIpAddress/text()"os,
      private_dns_name: ~x"./privateDnsName/text()"os,
      source_dest_check: ~x"./sourceDestCheck/text()"s,
      interface_type: ~x"./interfaceType/text()"os,
      outpost_arn: ~x"./outpostArn/text()"os,
      deny_all_igw_traffic: ~x"./denyAllIgwTraffic/text()"os,
      ipv6_native: ~x"./ipv6Native/text()"os,
      ipv6_address: ~x"./ipv6Address/text()"os,
      operator: [
        ~x"./operator"o,
        managed: ~x"./managed/text()"os,
        principal: ~x"./principal/text()"os
      ],
      connection_tracking_configuration: [
        ~x"./connectionTrackingConfiguration"o,
        tcp_established_timeout: ~x"./tcpEstablishedTimeout/text()"oi,
        udp_stream_timeout: ~x"./udpStreamTimeout/text()"oi,
        udp_timeout: ~x"./udpTimeout/text()"oi
      ],
      ipv4_prefix_set: [~x"./ipv4PrefixSet/item"l, ipv4_prefix: ~x"./ipv4Prefix/text()"os],
      ipv6_prefix_set: [~x"./ipv6PrefixSet/item"l, ipv6_prefix: ~x"./ipv6Prefix/text()"os],
      group_set: [
        ~x"./groupSet/item"l,
        group_id: ~x"./groupId/text()"os,
        group_name: ~x"./groupName/text()"os
      ],
      attachment: [
        ~x"./attachment"o,
        attachment_id: ~x"./attachmentId/text()"os,
        instance_id: ~x"./instanceId/text()"os,
        instance_owner_id: ~x"./instanceOwnerId/text()"os,
        device_index: ~x"./deviceIndex/text()"oi,
        network_card_index: ~x"./networkCardIndex/text()"oi,
        status: ~x"./status/text()"os,
        attach_time: ~x"./attachTime/text()"os,
        delete_on_termination: ~x"./deleteOnTermination/text()"os
      ],
      association: [
        ~x"./association"o,
        public_ip: ~x"./publicIp/text()"os,
        public_dns_name: ~x"./publicDnsName/text()"os,
        ip_owner_id: ~x"./ipOwnerId/text()"os,
        allocation_id: ~x"./allocationId/text()"os,
        association_id: ~x"./associationId/text()"os,
        carrier_ip: ~x"./carrierIp/text()"os,
        customer_owned_ip: ~x"./customerOwnedIp/text()"os
      ],
      private_ip_addresses_set: [
        ~x"./privateIpAddressesSet/item"l,
        private_ip_address: ~x"./privateIpAddress/text()"os,
        private_dns_name: ~x"./privateDnsName/text()"os,
        primary: ~x"./primary/text()"os,
        association: [
          ~x"./association"o,
          public_ip: ~x"./publicIp/text()"os,
          public_dns_name: ~x"./publicDnsName/text()"os,
          ip_owner_id: ~x"./ipOwnerId/text()"os
        ]
      ],
      ipv6_addresses_set: [
        ~x"./ipv6AddressesSet/item"l,
        ipv6_address: ~x"./ipv6Address/text()"os,
        is_primary_ipv6: ~x"./isPrimaryIpv6/text()"os
      ],
      tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
    )

  %{
    network_interface_set: Enum.map(enis, &coerce_network_interface/1),
    next_token: xpath(body, ~x"//DescribeNetworkInterfacesResponse/nextToken/text()"os)
  }
end

defp coerce_network_interface(%{requester_managed: managed, source_dest_check: check} = eni) do
  %{eni | requester_managed: managed === "true", source_dest_check: check === "true"}
end
```

Sandbox wiring per recipe B, arity 1, key `"*"`; delegate `sandbox_describe_network_interfaces_response(opts)` / stub `(_)`.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 DescribeNetworkInterfaces"
```

---

### Task 12: EC2 `describe_instance_status`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex`, `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `put_member_list/3`, `put_filters/2`, `maybe_put/3`.
- Produces: `AwsSdk.EC2.describe_instance_status(opts) :: {:ok, %{instance_status_set: [map()], next_token: String.t() | nil}} | {:error, term()}`; `parse_describe_instance_status_for_test/1`; `Sandbox.set_describe_instance_status_responses/1` (key `"*"`).

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "DescribeInstanceStatus keeps both status structures with details and events" do
  xml = """
  <DescribeInstanceStatusResponse><instanceStatusSet><item>
  <instanceId>i-1</instanceId><availabilityZone>us-east-1a</availabilityZone>
  <instanceState><code>16</code><name>running</name></instanceState>
  <systemStatus><status>ok</status>
  <details><item><name>reachability</name><status>passed</status></item></details>
  </systemStatus>
  <instanceStatus><status>impaired</status>
  <details><item><name>reachability</name><status>failed</status>
  <impairedSince>2026-08-05T11:00:00Z</impairedSince></item></details>
  </instanceStatus>
  <eventsSet><item><instanceEventId>event-1</instanceEventId>
  <code>system-reboot</code><description>scheduled reboot</description>
  <notBefore>2026-08-10T00:00:00Z</notBefore></item></eventsSet>
  </item></instanceStatusSet></DescribeInstanceStatusResponse>
  """

  parsed = AwsSdk.EC2.parse_describe_instance_status_for_test(xml)

  assert [status] = parsed.instance_status_set
  assert status.instance_id == "i-1"
  assert status.instance_state == %{code: 16, name: "running"}
  assert status.system_status.status == "ok"
  assert [sys_detail] = status.system_status.details
  assert sys_detail.status == "passed"
  assert status.instance_status.status == "impaired"
  assert [inst_detail] = status.instance_status.details
  assert inst_detail.impaired_since == "2026-08-05T11:00:00Z"
  assert [event] = status.events_set
  assert event.code == "system-reboot"
  assert parsed.next_token == nil
end
```

Sandbox:

```elixir
describe "describe_instance_status/1" do
  test "returns the registered statuses" do
    Sandbox.set_describe_instance_status_responses([
      fn ->
        {:ok, %{instance_status_set: [%{instance_id: "i-1"}], next_token: nil}}
      end
    ])

    assert {:ok, %{instance_status_set: [%{instance_id: "i-1"}]}} =
             EC2.describe_instance_status(
               instance_ids: ["i-1"],
               include_all_instances: true,
               sandbox: [enabled: true]
             )
  end
end
```

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

```elixir
@doc """
Describes the status of the specified instances (system status and
instance status checks, plus scheduled events).

## Options

  * `:instance_ids` - List of instance IDs, encoded as `InstanceId.N`.
  * `:include_all_instances` - Boolean; when `true`, includes stopped
    instances instead of only running ones.
  * `:filters` - List of `%{name:, values:}` filters.
  * `:next_token`, `:max_results` - Pagination.

## Examples

    AwsSdk.EC2.describe_instance_status(instance_ids: ["i-0abc"], include_all_instances: true)
    #=> {:ok,
    #=>  %{
    #=>    instance_status_set: [
    #=>      %{
    #=>        instance_id: "i-0abc",
    #=>        availability_zone: "us-east-1a",
    #=>        outpost_arn: nil,
    #=>        operator: nil,
    #=>        instance_state: %{code: 16, name: "running"},
    #=>        system_status: %{
    #=>          status: "ok",
    #=>          details: [%{name: "reachability", status: "passed", impaired_since: nil}]
    #=>        },
    #=>        instance_status: %{
    #=>          status: "ok",
    #=>          details: [%{name: "reachability", status: "passed", impaired_since: nil}]
    #=>        },
    #=>        attached_ebs_status: nil,
    #=>        events_set: []
    #=>      }
    #=>    ],
    #=>    next_token: nil
    #=>  }}
"""
@spec describe_instance_status(opts :: keyword()) ::
        {:ok, %{instance_status_set: list(map()), next_token: String.t() | nil}}
        | {:error, term()}
def describe_instance_status(opts \\ []) do
  if sandbox?(opts) do
    sandbox_describe_instance_status_response(opts)
  else
    do_describe_instance_status(opts)
  end
end

defp do_describe_instance_status(opts) do
  params =
    %{}
    |> put_member_list("InstanceId", opts[:instance_ids] || [])
    |> put_filters(opts[:filters] || [])
    |> maybe_put("IncludeAllInstances", opts[:include_all_instances])
    |> maybe_put("NextToken", opts[:next_token])
    |> maybe_put("MaxResults", opts[:max_results])

  with {:ok, op} <- build_operation("DescribeInstanceStatus", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_describe_instance_status(body)}
  end
end

@doc false
def parse_describe_instance_status_for_test(xml), do: parse_describe_instance_status(xml)

defp parse_describe_instance_status(body) do
  %{
    instance_status_set:
      xpath(body, ~x"//instanceStatusSet/item"l,
        instance_id: ~x"./instanceId/text()"s,
        availability_zone: ~x"./availabilityZone/text()"os,
        availability_zone_id: ~x"./availabilityZoneId/text()"os,
        outpost_arn: ~x"./outpostArn/text()"os,
        operator: [
          ~x"./operator"o,
          managed: ~x"./managed/text()"os,
          principal: ~x"./principal/text()"os
        ],
        instance_state: [
          ~x"./instanceState"o,
          code: ~x"./code/text()"oi,
          name: ~x"./name/text()"os
        ],
        system_status: [~x"./systemStatus"o | instance_status_summary_fields()],
        instance_status: [~x"./instanceStatus"o | instance_status_summary_fields()],
        attached_ebs_status: [~x"./attachedEbsStatus"o | instance_status_summary_fields()],
        events_set: [
          ~x"./eventsSet/item"l,
          instance_event_id: ~x"./instanceEventId/text()"os,
          code: ~x"./code/text()"os,
          description: ~x"./description/text()"os,
          not_before: ~x"./notBefore/text()"os,
          not_after: ~x"./notAfter/text()"os,
          not_before_deadline: ~x"./notBeforeDeadline/text()"os
        ]
      ),
    next_token: xpath(body, ~x"//DescribeInstanceStatusResponse/nextToken/text()"os)
  }
end

# InstanceStatusSummary: shared by systemStatus, instanceStatus, and
# attachedEbsStatus.
defp instance_status_summary_fields do
  [
    status: ~x"./status/text()"os,
    details: [
      ~x"./details/item"l,
      name: ~x"./name/text()"os,
      status: ~x"./status/text()"os,
      impaired_since: ~x"./impairedSince/text()"os
    ]
  ]
end
```

Sandbox wiring per recipe B, arity 1, key `"*"`; delegate `sandbox_describe_instance_status_response(opts)` / stub `(_)`.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 DescribeInstanceStatus"
```

---

### Task 13: EC2 `describe_iam_instance_profile_associations`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex`, `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `put_member_list/3`, `put_filters/2`, `maybe_put/3`.
- Produces: `AwsSdk.EC2.describe_iam_instance_profile_associations(opts) :: {:ok, %{iam_instance_profile_association_set: [map()], next_token: String.t() | nil}} | {:error, term()}`; `parse_describe_iam_instance_profile_associations_for_test/1`; `Sandbox.set_describe_iam_instance_profile_associations_responses/1` (key `"*"`).

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "DescribeIamInstanceProfileAssociations keeps the nested profile" do
  xml = """
  <DescribeIamInstanceProfileAssociationsResponse><iamInstanceProfileAssociationSet>
  <item><associationId>iip-assoc-1</associationId><instanceId>i-1</instanceId>
  <iamInstanceProfile><arn>arn:aws:iam::1:instance-profile/web</arn><id>AIPA1</id></iamInstanceProfile>
  <state>associated</state><timestamp>2026-01-01T00:00:00Z</timestamp></item>
  </iamInstanceProfileAssociationSet>
  <nextToken>tok</nextToken></DescribeIamInstanceProfileAssociationsResponse>
  """

  parsed = AwsSdk.EC2.parse_describe_iam_instance_profile_associations_for_test(xml)

  assert [assoc] = parsed.iam_instance_profile_association_set
  assert assoc.association_id == "iip-assoc-1"
  assert assoc.instance_id == "i-1"
  assert assoc.iam_instance_profile == %{arn: "arn:aws:iam::1:instance-profile/web", id: "AIPA1"}
  assert assoc.state == "associated"
  assert parsed.next_token == "tok"
end
```

Sandbox:

```elixir
describe "describe_iam_instance_profile_associations/1" do
  test "returns the registered associations" do
    Sandbox.set_describe_iam_instance_profile_associations_responses([
      fn ->
        {:ok,
         %{
           iam_instance_profile_association_set: [%{association_id: "iip-assoc-1"}],
           next_token: nil
         }}
      end
    ])

    assert {:ok, %{iam_instance_profile_association_set: [%{association_id: "iip-assoc-1"}]}} =
             EC2.describe_iam_instance_profile_associations(sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

```elixir
@doc """
Describes IAM instance profile associations.

## Options

  * `:association_ids` - List of association IDs, encoded as `AssociationId.N`.
  * `:filters` - List of `%{name:, values:}` filters (names: `"instance-id"`,
    `"state"`).
  * `:next_token`, `:max_results` - Pagination.

## Examples

    AwsSdk.EC2.describe_iam_instance_profile_associations(
      filters: [%{name: "instance-id", values: ["i-0abc"]}]
    )
    #=> {:ok,
    #=>  %{
    #=>    iam_instance_profile_association_set: [
    #=>      %{
    #=>        association_id: "iip-assoc-0abc",
    #=>        instance_id: "i-0abc",
    #=>        iam_instance_profile: %{
    #=>          arn: "arn:aws:iam::123456789012:instance-profile/web",
    #=>          id: "AIPAEXAMPLE"
    #=>        },
    #=>        state: "associated",
    #=>        timestamp: "2026-01-01T00:00:00Z"
    #=>      }
    #=>    ],
    #=>    next_token: nil
    #=>  }}
"""
@spec describe_iam_instance_profile_associations(opts :: keyword()) ::
        {:ok, %{iam_instance_profile_association_set: list(map()), next_token: String.t() | nil}}
        | {:error, term()}
def describe_iam_instance_profile_associations(opts \\ []) do
  if sandbox?(opts) do
    sandbox_describe_iam_instance_profile_associations_response(opts)
  else
    do_describe_iam_instance_profile_associations(opts)
  end
end

defp do_describe_iam_instance_profile_associations(opts) do
  params =
    %{}
    |> put_member_list("AssociationId", opts[:association_ids] || [])
    |> put_filters(opts[:filters] || [])
    |> maybe_put("NextToken", opts[:next_token])
    |> maybe_put("MaxResults", opts[:max_results])

  with {:ok, op} <- build_operation("DescribeIamInstanceProfileAssociations", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_describe_iam_instance_profile_associations(body)}
  end
end

@doc false
def parse_describe_iam_instance_profile_associations_for_test(xml),
  do: parse_describe_iam_instance_profile_associations(xml)

defp parse_describe_iam_instance_profile_associations(body) do
  %{
    iam_instance_profile_association_set:
      xpath(
        body,
        ~x"//iamInstanceProfileAssociationSet/item"l,
        association_id: ~x"./associationId/text()"s,
        instance_id: ~x"./instanceId/text()"os,
        iam_instance_profile: [
          ~x"./iamInstanceProfile"o,
          arn: ~x"./arn/text()"os,
          id: ~x"./id/text()"os
        ],
        state: ~x"./state/text()"os,
        timestamp: ~x"./timestamp/text()"os
      ),
    next_token:
      xpath(body, ~x"//DescribeIamInstanceProfileAssociationsResponse/nextToken/text()"os)
  }
end
```

Sandbox wiring per recipe B, arity 1, key `"*"`; delegate `sandbox_describe_iam_instance_profile_associations_response(opts)` / stub `(_)`.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 DescribeIamInstanceProfileAssociations"
```

---

### Task 14: EC2 Reachability Analyzer quartet

`create_network_insights_path`, `start_network_insights_analysis`, `describe_network_insights_analyses`, `delete_network_insights_path` — one commit; the four only make sense together (create → start → poll → clean up).

**Files:**
- Modify: `lib/aws_sdk/ec2.ex` (new "Reachability Analyzer" section), `lib/aws_sdk/ec2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/ec2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `put_member_list/3`, `put_filters/2`, `maybe_put/3`.
- Produces:
  - `AwsSdk.EC2.create_network_insights_path(source :: String.t(), destination :: String.t(), protocol :: String.t(), opts) :: {:ok, %{network_insights_path: map()}} | {:error, term()}`
  - `AwsSdk.EC2.start_network_insights_analysis(path_id :: String.t(), opts) :: {:ok, %{network_insights_analysis: map()}} | {:error, term()}`
  - `AwsSdk.EC2.describe_network_insights_analyses(opts) :: {:ok, %{network_insights_analysis_set: [map()], next_token: String.t() | nil}} | {:error, term()}`
  - `AwsSdk.EC2.delete_network_insights_path(path_id :: String.t(), opts) :: {:ok, %{network_insights_path_id: String.t()}} | {:error, term()}`
  - `parse_*_for_test/1` for each; sandbox setters `set_create_network_insights_path_responses/1` (keyed off `source`), `set_start_network_insights_analysis_responses/1` (keyed off `path_id`), `set_describe_network_insights_analyses_responses/1` (key `"*"`), `set_delete_network_insights_path_responses/1` (keyed off `path_id`).

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "CreateNetworkInsightsPath keeps the full path shape" do
  xml = """
  <CreateNetworkInsightsPathResponse><networkInsightsPath>
  <networkInsightsPathId>nip-1</networkInsightsPathId>
  <networkInsightsPathArn>arn:aws:ec2:us-east-1:1:network-insights-path/nip-1</networkInsightsPathArn>
  <createdDate>2026-08-05T12:00:00Z</createdDate>
  <source>i-1</source><destination>i-2</destination>
  <sourceArn>arn:aws:ec2:us-east-1:1:instance/i-1</sourceArn>
  <destinationArn>arn:aws:ec2:us-east-1:1:instance/i-2</destinationArn>
  <protocol>tcp</protocol><destinationPort>443</destinationPort>
  <tagSet/></networkInsightsPath></CreateNetworkInsightsPathResponse>
  """

  parsed = AwsSdk.EC2.parse_create_network_insights_path_for_test(xml)

  path = parsed.network_insights_path
  assert path.network_insights_path_id == "nip-1"
  assert path.source == "i-1"
  assert path.destination == "i-2"
  assert path.protocol == "tcp"
  assert path.destination_port == 443
end

test "StartNetworkInsightsAnalysis keeps the initial analysis state" do
  xml = """
  <StartNetworkInsightsAnalysisResponse><networkInsightsAnalysis>
  <networkInsightsAnalysisId>nia-1</networkInsightsAnalysisId>
  <networkInsightsAnalysisArn>arn:aws:ec2:us-east-1:1:network-insights-analysis/nia-1</networkInsightsAnalysisArn>
  <networkInsightsPathId>nip-1</networkInsightsPathId>
  <startDate>2026-08-05T12:00:00Z</startDate>
  <status>running</status>
  </networkInsightsAnalysis></StartNetworkInsightsAnalysisResponse>
  """

  parsed = AwsSdk.EC2.parse_start_network_insights_analysis_for_test(xml)

  analysis = parsed.network_insights_analysis
  assert analysis.network_insights_analysis_id == "nia-1"
  assert analysis.status == "running"
  assert analysis.network_path_found == nil
end

test "DescribeNetworkInsightsAnalyses keeps status, path-found flag, and explanations" do
  xml = """
  <DescribeNetworkInsightsAnalysesResponse><networkInsightsAnalysisSet><item>
  <networkInsightsAnalysisId>nia-1</networkInsightsAnalysisId>
  <networkInsightsPathId>nip-1</networkInsightsPathId>
  <startDate>2026-08-05T12:00:00Z</startDate>
  <status>succeeded</status><networkPathFound>false</networkPathFound>
  <explanationSet><item>
  <direction>ingress</direction><explanationCode>ENI_SG_RULES_MISMATCH</explanationCode>
  <networkInterface><id>eni-1</id><arn>arn:aws:ec2:us-east-1:1:network-interface/eni-1</arn></networkInterface>
  <securityGroupSet><item><id>sg-1</id></item></securityGroupSet>
  <port>443</port>
  </item></explanationSet>
  <forwardPathComponentSet><item>
  <sequenceNumber>1</sequenceNumber>
  <component><id>i-1</id><name>web</name></component>
  <subnet><id>subnet-1</id></subnet>
  <outboundHeader><protocol>6</protocol>
  <sourceAddressSet><item>10.0.1.5/32</item></sourceAddressSet>
  <destinationAddressSet><item>10.0.2.9/32</item></destinationAddressSet>
  <destinationPortRangeSet><item><from>443</from><to>443</to></item></destinationPortRangeSet>
  </outboundHeader>
  </item></forwardPathComponentSet>
  </item></networkInsightsAnalysisSet></DescribeNetworkInsightsAnalysesResponse>
  """

  parsed = AwsSdk.EC2.parse_describe_network_insights_analyses_for_test(xml)

  assert [analysis] = parsed.network_insights_analysis_set
  assert analysis.status == "succeeded"
  assert analysis.network_path_found == false
  assert [explanation] = analysis.explanation_set
  assert explanation.explanation_code == "ENI_SG_RULES_MISMATCH"
  assert explanation.network_interface.id == "eni-1"
  assert explanation.security_groups == [%{id: "sg-1", arn: nil, name: nil}]
  assert explanation.port == 443
  assert [hop] = analysis.forward_path_component_set
  assert hop.sequence_number == 1
  assert hop.component.id == "i-1"
  assert hop.outbound_header.destination_port_ranges == [%{from: 443, to: 443}]
  assert parsed.next_token == nil
end

test "DeleteNetworkInsightsPath returns the deleted path id" do
  xml = """
  <DeleteNetworkInsightsPathResponse>
  <networkInsightsPathId>nip-1</networkInsightsPathId>
  </DeleteNetworkInsightsPathResponse>
  """

  parsed = AwsSdk.EC2.parse_delete_network_insights_path_for_test(xml)

  assert parsed.network_insights_path_id == "nip-1"
end
```

Sandbox:

```elixir
describe "create_network_insights_path/4" do
  test "keys off the source" do
    Sandbox.set_create_network_insights_path_responses([
      {"i-1", fn -> {:ok, %{network_insights_path: %{network_insights_path_id: "nip-1"}}} end}
    ])

    assert {:ok, %{network_insights_path: %{network_insights_path_id: "nip-1"}}} =
             EC2.create_network_insights_path("i-1", "i-2", "tcp",
               destination_port: 443,
               sandbox: [enabled: true]
             )
  end
end

describe "start_network_insights_analysis/2" do
  test "keys off the path id" do
    Sandbox.set_start_network_insights_analysis_responses([
      {"nip-1",
       fn ->
         {:ok, %{network_insights_analysis: %{network_insights_analysis_id: "nia-1", status: "running"}}}
       end}
    ])

    assert {:ok, %{network_insights_analysis: %{status: "running"}}} =
             EC2.start_network_insights_analysis("nip-1", sandbox: [enabled: true])
  end
end

describe "describe_network_insights_analyses/1" do
  test "returns the registered analyses" do
    Sandbox.set_describe_network_insights_analyses_responses([
      fn ->
        {:ok,
         %{
           network_insights_analysis_set: [%{status: "succeeded", network_path_found: true}],
           next_token: nil
         }}
      end
    ])

    assert {:ok, %{network_insights_analysis_set: [%{network_path_found: true}]}} =
             EC2.describe_network_insights_analyses(
               analysis_ids: ["nia-1"],
               sandbox: [enabled: true]
             )
  end
end

describe "delete_network_insights_path/2" do
  test "keys off the path id" do
    Sandbox.set_delete_network_insights_path_responses([
      {"nip-1", fn -> {:ok, %{network_insights_path_id: "nip-1"}} end}
    ])

    assert {:ok, %{network_insights_path_id: "nip-1"}} =
             EC2.delete_network_insights_path("nip-1", sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

New "Reachability Analyzer" section in `ec2.ex`:

```elixir
# ---------------------------------------------------------------------------
# Reachability Analyzer
# ---------------------------------------------------------------------------

@doc """
Creates a Reachability Analyzer path between a source and a destination.

`destination` is positional even though AWS marks it optional (the
alternative is `FilterAtDestination`), because a deployd reachability
check always names both endpoints.

`ClientToken` is required by AWS for idempotency; one is generated per
call unless `:client_token` is supplied.

## Arguments

  * `source` - Source resource ID or ARN (instance, ENI, IGW, ...).
  * `destination` - Destination resource ID or ARN.
  * `protocol` - `"tcp"` or `"udp"`.

## Options

  * `:destination_port` - Destination port to analyze.
  * `:source_ip`, `:destination_ip` - Override IPs within the resources.
  * `:client_token` - Idempotency token (auto-generated when omitted).

## Examples

    AwsSdk.EC2.create_network_insights_path("i-0aaa", "i-0bbb", "tcp", destination_port: 443)
    #=> {:ok,
    #=>  %{
    #=>    network_insights_path: %{
    #=>      network_insights_path_id: "nip-0abc",
    #=>      network_insights_path_arn: "arn:aws:ec2:us-east-1:123456789012:network-insights-path/nip-0abc",
    #=>      created_date: "2026-08-05T12:00:00Z",
    #=>      source: "i-0aaa",
    #=>      destination: "i-0bbb",
    #=>      source_arn: "arn:aws:ec2:us-east-1:123456789012:instance/i-0aaa",
    #=>      destination_arn: "arn:aws:ec2:us-east-1:123456789012:instance/i-0bbb",
    #=>      source_ip: nil,
    #=>      destination_ip: nil,
    #=>      protocol: "tcp",
    #=>      destination_port: 443,
    #=>      tag_set: []
    #=>    }
    #=>  }}
"""
@spec create_network_insights_path(
        source :: String.t(),
        destination :: String.t(),
        protocol :: String.t(),
        opts :: keyword()
      ) :: {:ok, %{network_insights_path: map()}} | {:error, term()}
def create_network_insights_path(source, destination, protocol, opts \\ [])
    when is_binary(source) and is_binary(destination) and is_binary(protocol) do
  if sandbox?(opts) do
    sandbox_create_network_insights_path_response(source, destination, protocol, opts)
  else
    do_create_network_insights_path(source, destination, protocol, opts)
  end
end

defp do_create_network_insights_path(source, destination, protocol, opts) do
  params =
    %{
      "Source" => source,
      "Destination" => destination,
      "Protocol" => protocol,
      "ClientToken" => client_token(opts)
    }
    |> maybe_put("DestinationPort", opts[:destination_port])
    |> maybe_put("SourceIp", opts[:source_ip])
    |> maybe_put("DestinationIp", opts[:destination_ip])

  with {:ok, op} <- build_operation("CreateNetworkInsightsPath", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_create_network_insights_path(body)}
  end
end

@doc false
def parse_create_network_insights_path_for_test(xml),
  do: parse_create_network_insights_path(xml)

defp parse_create_network_insights_path(body) do
  %{
    network_insights_path:
      xpath(body, ~x"//networkInsightsPath"e,
        network_insights_path_id: ~x"./networkInsightsPathId/text()"s,
        network_insights_path_arn: ~x"./networkInsightsPathArn/text()"os,
        created_date: ~x"./createdDate/text()"os,
        source: ~x"./source/text()"os,
        destination: ~x"./destination/text()"os,
        source_arn: ~x"./sourceArn/text()"os,
        destination_arn: ~x"./destinationArn/text()"os,
        source_ip: ~x"./sourceIp/text()"os,
        destination_ip: ~x"./destinationIp/text()"os,
        protocol: ~x"./protocol/text()"os,
        destination_port: ~x"./destinationPort/text()"oi,
        filter_at_source: [~x"./filterAtSource"o | path_filter_fields()],
        filter_at_destination: [~x"./filterAtDestination"o | path_filter_fields()],
        tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
      )
  }
end

# PathFilter, shared by filterAtSource and filterAtDestination.
defp path_filter_fields do
  [
    source_address: ~x"./sourceAddress/text()"os,
    source_port_range: [
      ~x"./sourcePortRange"o,
      from_port: ~x"./fromPort/text()"oi,
      to_port: ~x"./toPort/text()"oi
    ],
    destination_address: ~x"./destinationAddress/text()"os,
    destination_port_range: [
      ~x"./destinationPortRange"o,
      from_port: ~x"./fromPort/text()"oi,
      to_port: ~x"./toPort/text()"oi
    ]
  ]
end

@doc """
Starts analysing a Reachability Analyzer path.

`ClientToken` is auto-generated unless `:client_token` is supplied.

## Examples

    AwsSdk.EC2.start_network_insights_analysis("nip-0abc")
    #=> {:ok,
    #=>  %{
    #=>    network_insights_analysis: %{
    #=>      network_insights_analysis_id: "nia-0abc",
    #=>      network_insights_analysis_arn: "arn:aws:ec2:us-east-1:123456789012:network-insights-analysis/nia-0abc",
    #=>      network_insights_path_id: "nip-0abc",
    #=>      start_date: "2026-08-05T12:00:00Z",
    #=>      status: "running",
    #=>      status_message: nil,
    #=>      network_path_found: nil,
    #=>      ...
    #=>    }
    #=>  }}

Poll with `describe_network_insights_analyses/1` until `:status` is
`"succeeded"` (or `"failed"`), then read `:network_path_found` and
`:explanation_set`.
"""
@spec start_network_insights_analysis(path_id :: String.t(), opts :: keyword()) ::
        {:ok, %{network_insights_analysis: map()}} | {:error, term()}
def start_network_insights_analysis(path_id, opts \\ []) when is_binary(path_id) do
  if sandbox?(opts) do
    sandbox_start_network_insights_analysis_response(path_id, opts)
  else
    do_start_network_insights_analysis(path_id, opts)
  end
end

defp do_start_network_insights_analysis(path_id, opts) do
  params = %{"NetworkInsightsPathId" => path_id, "ClientToken" => client_token(opts)}

  with {:ok, op} <- build_operation("StartNetworkInsightsAnalysis", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_start_network_insights_analysis(body)}
  end
end

@doc false
def parse_start_network_insights_analysis_for_test(xml),
  do: parse_start_network_insights_analysis(xml)

defp parse_start_network_insights_analysis(body) do
  result =
    xpath(body, ~x"//StartNetworkInsightsAnalysisResponse"e,
      network_insights_analysis: [
        ~x"./networkInsightsAnalysis"o | network_insights_analysis_fields()
      ]
    )

  %{network_insights_analysis: coerce_network_path_found(result.network_insights_analysis)}
end

@doc """
Describes Reachability Analyzer analyses.

deployd's polling loop: call with `:analysis_ids` until `:status` is
`"succeeded"`, then branch on `:network_path_found` and report
`:explanation_set` when the path was not found.

## Options

  * `:analysis_ids` - List of analysis IDs, encoded as `NetworkInsightsAnalysisId.N`.
  * `:path_id` - Restrict to analyses of one path (`NetworkInsightsPathId`).
  * `:filters` - List of `%{name:, values:}` filters.
  * `:next_token`, `:max_results` - Pagination.

## Examples

    AwsSdk.EC2.describe_network_insights_analyses(analysis_ids: ["nia-0abc"])
    #=> {:ok,
    #=>  %{
    #=>    network_insights_analysis_set: [
    #=>      %{
    #=>        network_insights_analysis_id: "nia-0abc",
    #=>        network_insights_path_id: "nip-0abc",
    #=>        start_date: "2026-08-05T12:00:00Z",
    #=>        status: "succeeded",
    #=>        status_message: nil,
    #=>        warning_message: nil,
    #=>        network_path_found: false,
    #=>        explanation_set: [
    #=>          %{
    #=>            direction: "ingress",
    #=>            explanation_code: "ENI_SG_RULES_MISMATCH",
    #=>            network_interface: %{id: "eni-1", arn: "...", name: nil},
    #=>            security_groups: [%{id: "sg-1", arn: nil, name: nil}],
    #=>            port: 443,
    #=>            ...
    #=>          }
    #=>        ],
    #=>        forward_path_component_set: [...],
    #=>        return_path_component_set: [],
    #=>        tag_set: []
    #=>      }
    #=>    ],
    #=>    next_token: nil
    #=>  }}
"""
@spec describe_network_insights_analyses(opts :: keyword()) ::
        {:ok, %{network_insights_analysis_set: list(map()), next_token: String.t() | nil}}
        | {:error, term()}
def describe_network_insights_analyses(opts \\ []) do
  if sandbox?(opts) do
    sandbox_describe_network_insights_analyses_response(opts)
  else
    do_describe_network_insights_analyses(opts)
  end
end

defp do_describe_network_insights_analyses(opts) do
  params =
    %{}
    |> put_member_list("NetworkInsightsAnalysisId", opts[:analysis_ids] || [])
    |> maybe_put("NetworkInsightsPathId", opts[:path_id])
    |> put_filters(opts[:filters] || [])
    |> maybe_put("NextToken", opts[:next_token])
    |> maybe_put("MaxResults", opts[:max_results])

  with {:ok, op} <- build_operation("DescribeNetworkInsightsAnalyses", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_describe_network_insights_analyses(body)}
  end
end

@doc false
def parse_describe_network_insights_analyses_for_test(xml),
  do: parse_describe_network_insights_analyses(xml)

defp parse_describe_network_insights_analyses(body) do
  result =
    xpath(body, ~x"//DescribeNetworkInsightsAnalysesResponse"e,
      network_insights_analysis_set: [
        ~x"./networkInsightsAnalysisSet/item"l | network_insights_analysis_fields()
      ]
    )

  %{
    network_insights_analysis_set:
      Enum.map(result.network_insights_analysis_set, &coerce_network_path_found/1),
    next_token: xpath(body, ~x"//DescribeNetworkInsightsAnalysesResponse/nextToken/text()"os)
  }
end

@doc """
Deletes a Reachability Analyzer path. Any analyses of the path must be
deleted first (AWS rejects the call otherwise).

## Examples

    AwsSdk.EC2.delete_network_insights_path("nip-0abc")
    #=> {:ok, %{network_insights_path_id: "nip-0abc"}}
"""
@spec delete_network_insights_path(path_id :: String.t(), opts :: keyword()) ::
        {:ok, %{network_insights_path_id: String.t()}} | {:error, term()}
def delete_network_insights_path(path_id, opts \\ []) when is_binary(path_id) do
  if sandbox?(opts) do
    sandbox_delete_network_insights_path_response(path_id, opts)
  else
    do_delete_network_insights_path(path_id, opts)
  end
end

defp do_delete_network_insights_path(path_id, opts) do
  with {:ok, op} <- build_operation("DeleteNetworkInsightsPath", %{"NetworkInsightsPathId" => path_id}, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_delete_network_insights_path(body)}
  end
end

@doc false
def parse_delete_network_insights_path_for_test(xml),
  do: parse_delete_network_insights_path(xml)

defp parse_delete_network_insights_path(body) do
  %{
    network_insights_path_id:
      xpath(body, ~x"//DeleteNetworkInsightsPathResponse/networkInsightsPathId/text()"s)
  }
end

# NetworkInsightsAnalysis, shared by Start and Describe (both return the
# same structure). networkPathFound is coerced afterwards because it is
# the field deployd branches on.
defp network_insights_analysis_fields do
  [
    network_insights_analysis_id: ~x"./networkInsightsAnalysisId/text()"s,
    network_insights_analysis_arn: ~x"./networkInsightsAnalysisArn/text()"os,
    network_insights_path_id: ~x"./networkInsightsPathId/text()"os,
    additional_account_set: ~x"./additionalAccountSet/item/text()"sl,
    filter_in_arn_set: ~x"./filterInArnSet/item/text()"sl,
    filter_out_arn_set: ~x"./filterOutArnSet/item/text()"sl,
    start_date: ~x"./startDate/text()"os,
    status: ~x"./status/text()"os,
    status_message: ~x"./statusMessage/text()"os,
    warning_message: ~x"./warningMessage/text()"os,
    network_path_found: ~x"./networkPathFound/text()"os,
    forward_path_component_set: [~x"./forwardPathComponentSet/item"l | path_component_fields()],
    return_path_component_set: [~x"./returnPathComponentSet/item"l | path_component_fields()],
    explanation_set: [~x"./explanationSet/item"l | explanation_fields()],
    alternate_path_hint_set: [
      ~x"./alternatePathHintSet/item"l,
      component_id: ~x"./componentId/text()"os,
      component_arn: ~x"./componentArn/text()"os
    ],
    suggested_account_set: ~x"./suggestedAccountSet/item/text()"sl,
    tag_set: [~x"./tagSet/item"l, key: ~x"./key/text()"s, value: ~x"./value/text()"s]
  ]
end

defp coerce_network_path_found(nil), do: nil

# A running analysis has no networkPathFound yet; keep the nil rather
# than coercing it to false, so callers can tell "not finished" from
# "unreachable".
defp coerce_network_path_found(%{network_path_found: nil} = analysis), do: analysis

defp coerce_network_path_found(%{network_path_found: value} = analysis) do
  %{analysis | network_path_found: value === "true"}
end

# AnalysisComponent — the {id, arn, name} triple AWS uses for every
# referenced resource in an analysis.
defp analysis_component_fields do
  [id: ~x"./id/text()"os, arn: ~x"./arn/text()"os, name: ~x"./name/text()"os]
end

# PathComponent (one hop of the analysed path).
defp path_component_fields do
  [
    sequence_number: ~x"./sequenceNumber/text()"oi,
    acl_rule: [~x"./aclRule"o | analysis_acl_rule_fields()],
    attached_to: [~x"./attachedTo"o | analysis_component_fields()],
    component: [~x"./component"o | analysis_component_fields()],
    destination_vpc: [~x"./destinationVpc"o | analysis_component_fields()],
    source_vpc: [~x"./sourceVpc"o | analysis_component_fields()],
    subnet: [~x"./subnet"o | analysis_component_fields()],
    vpc: [~x"./vpc"o | analysis_component_fields()],
    transit_gateway: [~x"./transitGateway"o | analysis_component_fields()],
    elastic_load_balancer_listener: [
      ~x"./elasticLoadBalancerListener"o | analysis_component_fields()
    ],
    outbound_header: [~x"./outboundHeader"o | analysis_packet_header_fields()],
    inbound_header: [~x"./inboundHeader"o | analysis_packet_header_fields()],
    route_table_route: [~x"./routeTableRoute"o | analysis_route_table_route_fields()],
    transit_gateway_route_table_route: [
      ~x"./transitGatewayRouteTableRoute"o,
      destination_cidr: ~x"./destinationCidr/text()"os,
      state: ~x"./state/text()"os,
      route_origin: ~x"./routeOrigin/text()"os,
      prefix_list_id: ~x"./prefixListId/text()"os,
      attachment_id: ~x"./attachmentId/text()"os,
      resource_id: ~x"./resourceId/text()"os,
      resource_type: ~x"./resourceType/text()"os
    ],
    security_group_rule: [~x"./securityGroupRule"o | analysis_security_group_rule_fields()],
    additional_detail_set: [
      ~x"./additionalDetailSet/item"l,
      additional_detail_type: ~x"./additionalDetailType/text()"os,
      component: [~x"./component"o | analysis_component_fields()]
    ],
    explanation_set: [~x"./explanationSet/item"l | explanation_fields()],
    firewall_stateless_rule: [~x"./firewallStatelessRule"o | firewall_stateless_rule_fields()],
    firewall_stateful_rule: [~x"./firewallStatefulRule"o | firewall_stateful_rule_fields()],
    service_name: ~x"./serviceName/text()"os
  ]
end

# AnalysisPacketHeader.
defp analysis_packet_header_fields do
  [
    protocol: ~x"./protocol/text()"os,
    source_addresses: ~x"./sourceAddressSet/item/text()"sl,
    destination_addresses: ~x"./destinationAddressSet/item/text()"sl,
    source_port_ranges: [
      ~x"./sourcePortRangeSet/item"l,
      from: ~x"./from/text()"oi,
      to: ~x"./to/text()"oi
    ],
    destination_port_ranges: [
      ~x"./destinationPortRangeSet/item"l,
      from: ~x"./from/text()"oi,
      to: ~x"./to/text()"oi
    ]
  ]
end

# AnalysisAclRule.
defp analysis_acl_rule_fields do
  [
    cidr: ~x"./cidr/text()"os,
    egress: ~x"./egress/text()"os,
    protocol: ~x"./protocol/text()"os,
    rule_action: ~x"./ruleAction/text()"os,
    rule_number: ~x"./ruleNumber/text()"oi,
    port_range: [~x"./portRange"o, from: ~x"./from/text()"oi, to: ~x"./to/text()"oi]
  ]
end

# AnalysisRouteTableRoute.
defp analysis_route_table_route_fields do
  [
    destination_cidr: ~x"./destinationCidr/text()"os,
    destination_prefix_list_id: ~x"./destinationPrefixListId/text()"os,
    egress_only_internet_gateway_id: ~x"./egressOnlyInternetGatewayId/text()"os,
    gateway_id: ~x"./gatewayId/text()"os,
    instance_id: ~x"./instanceId/text()"os,
    nat_gateway_id: ~x"./natGatewayId/text()"os,
    network_interface_id: ~x"./networkInterfaceId/text()"os,
    origin: ~x"./origin/text()"os,
    transit_gateway_id: ~x"./transitGatewayId/text()"os,
    vpc_peering_connection_id: ~x"./vpcPeeringConnectionId/text()"os,
    state: ~x"./state/text()"os,
    carrier_gateway_id: ~x"./carrierGatewayId/text()"os,
    core_network_arn: ~x"./coreNetworkArn/text()"os,
    local_gateway_id: ~x"./localGatewayId/text()"os
  ]
end

# AnalysisSecurityGroupRule.
defp analysis_security_group_rule_fields do
  [
    cidr: ~x"./cidr/text()"os,
    direction: ~x"./direction/text()"os,
    security_group_id: ~x"./securityGroupId/text()"os,
    port_range: [~x"./portRange"o, from: ~x"./from/text()"oi, to: ~x"./to/text()"oi],
    prefix_list_id: ~x"./prefixListId/text()"os,
    protocol: ~x"./protocol/text()"os
  ]
end

# Explanation — the structure Reachability Analyzer uses to say why a
# path is (un)reachable. Every member is an AnalysisComponent, a list of
# them, or a scalar.
defp explanation_fields do
  [
    direction: ~x"./direction/text()"os,
    explanation_code: ~x"./explanationCode/text()"os,
    state: ~x"./state/text()"os,
    address: ~x"./address/text()"os,
    addresses: ~x"./addressSet/item/text()"sl,
    cidrs: ~x"./cidrSet/item/text()"sl,
    packet_field: ~x"./packetField/text()"os,
    missing_component: ~x"./missingComponent/text()"os,
    port: ~x"./port/text()"oi,
    port_ranges: [~x"./portRangeSet/item"l, from: ~x"./from/text()"oi, to: ~x"./to/text()"oi],
    protocols: ~x"./protocolSet/item/text()"sl,
    load_balancer_arn: ~x"./loadBalancerArn/text()"os,
    load_balancer_listener_port: ~x"./loadBalancerListenerPort/text()"oi,
    load_balancer_target_port: ~x"./loadBalancerTargetPort/text()"oi,
    component_account: ~x"./componentAccount/text()"os,
    component_region: ~x"./componentRegion/text()"os,
    acl: [~x"./acl"o | analysis_component_fields()],
    acl_rule: [~x"./aclRule"o | analysis_acl_rule_fields()],
    attached_to: [~x"./attachedTo"o | analysis_component_fields()],
    availability_zones: ~x"./availabilityZoneSet/item/text()"sl,
    component: [~x"./component"o | analysis_component_fields()],
    customer_gateway: [~x"./customerGateway"o | analysis_component_fields()],
    destination: [~x"./destination"o | analysis_component_fields()],
    destination_vpc: [~x"./destinationVpc"o | analysis_component_fields()],
    source_vpc: [~x"./sourceVpc"o | analysis_component_fields()],
    ingress_route_table: [~x"./ingressRouteTable"o | analysis_component_fields()],
    internet_gateway: [~x"./internetGateway"o | analysis_component_fields()],
    classic_load_balancer_listener: [
      ~x"./classicLoadBalancerListener"o,
      load_balancer_port: ~x"./loadBalancerPort/text()"oi,
      instance_port: ~x"./instancePort/text()"oi
    ],
    load_balancer_target: [
      ~x"./loadBalancerTarget"o,
      address: ~x"./address/text()"os,
      availability_zone: ~x"./availabilityZone/text()"os,
      instance: [~x"./instance"o | analysis_component_fields()],
      port: ~x"./port/text()"oi
    ],
    load_balancer_target_group: [~x"./loadBalancerTargetGroup"o | analysis_component_fields()],
    load_balancer_target_groups: [
      ~x"./loadBalancerTargetGroupSet/item"l | analysis_component_fields()
    ],
    elastic_load_balancer_listener: [
      ~x"./elasticLoadBalancerListener"o | analysis_component_fields()
    ],
    nat_gateway: [~x"./natGateway"o | analysis_component_fields()],
    network_interface: [~x"./networkInterface"o | analysis_component_fields()],
    vpc_peering_connection: [~x"./vpcPeeringConnection"o | analysis_component_fields()],
    prefix_list: [~x"./prefixList"o | analysis_component_fields()],
    route_table: [~x"./routeTable"o | analysis_component_fields()],
    route_table_route: [~x"./routeTableRoute"o | analysis_route_table_route_fields()],
    security_group: [~x"./securityGroup"o | analysis_component_fields()],
    security_group_rule: [~x"./securityGroupRule"o | analysis_security_group_rule_fields()],
    security_groups: [~x"./securityGroupSet/item"l | analysis_component_fields()],
    subnet: [~x"./subnet"o | analysis_component_fields()],
    subnet_route_table: [~x"./subnetRouteTable"o | analysis_component_fields()],
    vpc: [~x"./vpc"o | analysis_component_fields()],
    vpn_connection: [~x"./vpnConnection"o | analysis_component_fields()],
    vpn_gateway: [~x"./vpnGateway"o | analysis_component_fields()],
    transit_gateway: [~x"./transitGateway"o | analysis_component_fields()],
    transit_gateway_attachment: [~x"./transitGatewayAttachment"o | analysis_component_fields()],
    transit_gateway_route_table: [~x"./transitGatewayRouteTable"o | analysis_component_fields()],
    vpc_endpoint: [~x"./vpcEndpoint"o | analysis_component_fields()],
    availability_zone_ids: ~x"./availabilityZoneIdSet/item/text()"sl,
    firewall_stateless_rule: [~x"./firewallStatelessRule"o | firewall_stateless_rule_fields()],
    firewall_stateful_rule: [~x"./firewallStatefulRule"o | firewall_stateful_rule_fields()]
  ]
end

# FirewallStatelessRule.
defp firewall_stateless_rule_fields do
  [
    rule_group_arn: ~x"./ruleGroupArn/text()"os,
    sources: ~x"./sourceSet/item/text()"sl,
    destinations: ~x"./destinationSet/item/text()"sl,
    source_ports: [~x"./sourcePortSet/item"l, from: ~x"./from/text()"oi, to: ~x"./to/text()"oi],
    destination_ports: [
      ~x"./destinationPortSet/item"l,
      from: ~x"./from/text()"oi,
      to: ~x"./to/text()"oi
    ],
    protocols: ~x"./protocolSet/item/text()"sl,
    rule_action: ~x"./ruleAction/text()"os,
    priority: ~x"./priority/text()"oi
  ]
end

# FirewallStatefulRule.
defp firewall_stateful_rule_fields do
  [
    rule_group_arn: ~x"./ruleGroupArn/text()"os,
    sources: ~x"./sourceSet/item/text()"sl,
    destinations: ~x"./destinationSet/item/text()"sl,
    source_ports: [~x"./sourcePortSet/item"l, from: ~x"./from/text()"oi, to: ~x"./to/text()"oi],
    destination_ports: [
      ~x"./destinationPortSet/item"l,
      from: ~x"./from/text()"oi,
      to: ~x"./to/text()"oi
    ],
    protocol: ~x"./protocol/text()"os,
    rule_action: ~x"./ruleAction/text()"os,
    direction: ~x"./direction/text()"os
  ]
end

# ClientToken is a wire-required idempotency token AWS's own SDKs
# auto-generate (botocore marks it idempotencyToken); nothing else in
# this library generates one, so it is generated here with :crypto,
# which the library already depends on (S3's Content-MD5 hashing).
defp client_token(opts) do
  opts[:client_token] || Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
end
```

Note for the reviewer: `client_token/1` is a genuinely new helper — nothing in `lib/` generates idempotency tokens, AWS requires the member on the wire, and `:crypto` is already a dependency (S3's Content-MD5 hashing). It is called out here so its addition is approved deliberately rather than slipping in.

Sandbox wiring per recipe B — four pairs in `ec2/sandbox.ex`:
- `create_network_insights_path_response(source, destination, protocol, opts)` keyed off `source`, `examples = AwsSdk.Sandbox.doc_examples([:source, :destination, :protocol])`, applying `[source, destination, protocol, opts]`
- `start_network_insights_analysis_response(path_id, opts)` keyed off `path_id`
- `describe_network_insights_analyses_response(opts)` key `"*"`
- `delete_network_insights_path_response(path_id, opts)` keyed off `path_id`

with the matching `set_*_responses` functions (all via `AwsSdk.Sandbox.normalize_no_key/1`), plus the four `defdelegate sandbox_*_response` entries and `else`-branch stubs in `ec2.ex` at the correct arities.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex lib/aws_sdk/ec2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/ec2/sandbox_test.exs
git commit -m "feat: EC2 Reachability Analyzer path/analysis lifecycle"
```

---

### Task 15: AutoScaling `describe_scaling_activities`

**Files:**
- Modify: `lib/aws_sdk/auto_scaling.ex` (public fn next to `describe_instance_refreshes`, parser next to `parse_describe_instance_refreshes`), `lib/aws_sdk/auto_scaling/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/auto_scaling/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `flatten_query/1`, `nilify/1` in `auto_scaling.ex`.
- Produces: `AwsSdk.AutoScaling.describe_scaling_activities(auto_scaling_group_name :: String.t(), opts) :: {:ok, %{activities: [map()], next_token: String.t() | nil}} | {:error, term()}`; `parse_describe_scaling_activities_for_test/1`; `Sandbox.set_describe_scaling_activities_responses/1` keyed off the group name.

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "DescribeScalingActivities keeps status, cause, and details" do
  xml = """
  <DescribeScalingActivitiesResponse><DescribeScalingActivitiesResult>
  <Activities><member>
  <ActivityId>act-1</ActivityId>
  <AutoScalingGroupName>web-asg</AutoScalingGroupName>
  <Description>Terminating EC2 instance: i-1</Description>
  <Cause>instance refresh</Cause>
  <StartTime>2026-08-05T12:00:00Z</StartTime>
  <EndTime>2026-08-05T12:05:00Z</EndTime>
  <StatusCode>Successful</StatusCode>
  <Progress>100</Progress>
  <Details>{"Subnet ID":"subnet-1"}</Details>
  <AutoScalingGroupARN>arn:aws:autoscaling:us-east-1:1:autoScalingGroup:x:autoScalingGroupName/web-asg</AutoScalingGroupARN>
  </member></Activities>
  <NextToken>tok</NextToken>
  </DescribeScalingActivitiesResult></DescribeScalingActivitiesResponse>
  """

  parsed = AwsSdk.AutoScaling.parse_describe_scaling_activities_for_test(xml)

  assert [activity] = parsed.activities
  assert activity.activity_id == "act-1"
  assert activity.auto_scaling_group_name == "web-asg"
  assert activity.status_code == "Successful"
  assert activity.status_message == nil
  assert activity.cause == "instance refresh"
  assert activity.progress == 100
  assert activity.details == ~s({"Subnet ID":"subnet-1"})
  assert parsed.next_token == "tok"
end
```

Sandbox (`test/aws_sdk/auto_scaling/sandbox_test.exs`, following that file's existing alias/describe conventions):

```elixir
describe "describe_scaling_activities/2" do
  test "keys off the group name" do
    Sandbox.set_describe_scaling_activities_responses([
      {"web-asg",
       fn ->
         {:ok, %{activities: [%{activity_id: "act-1", status_code: "InProgress"}], next_token: nil}}
       end}
    ])

    assert {:ok, %{activities: [%{status_code: "InProgress"}]}} =
             AutoScaling.describe_scaling_activities("web-asg",
               max_records: 10,
               sandbox: [enabled: true]
             )
  end
end
```

- [ ] **Step 2: Run to verify failure** — `mix test test/aws_sdk/conformance_test.exs test/aws_sdk/auto_scaling/sandbox_test.exs`, expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

Public function, mirroring `describe_instance_refreshes/2`:

```elixir
@doc """
Describes the scaling activities for an Auto Scaling group.

Maps to AWS `DescribeScalingActivities`. `auto_scaling_group_name` is
required here (AWS allows omitting it to list account-wide activity;
this wrapper scopes to one group, the deployd use).

## Options

  - `:activity_ids` - list of activity IDs to fetch
  - `:include_deleted_groups` - boolean; include activity from deleted groups
  - `:max_records` - page size (max 100)
  - `:next_token` - pagination token

## Examples

    AwsSdk.AutoScaling.describe_scaling_activities("web-asg", max_records: 10)
    #=> {:ok,
    #=>  %{
    #=>    activities: [
    #=>      %{
    #=>        activity_id: "act-0abc",
    #=>        auto_scaling_group_name: "web-asg",
    #=>        description: "Terminating EC2 instance: i-0abc",
    #=>        cause: "At 2026-08-05T12:00:00Z an instance refresh replaced instances",
    #=>        start_time: "2026-08-05T12:00:00Z",
    #=>        end_time: "2026-08-05T12:05:00Z",
    #=>        status_code: "Successful",
    #=>        status_message: nil,
    #=>        progress: 100,
    #=>        details: "{...}",
    #=>        auto_scaling_group_state: nil,
    #=>        auto_scaling_group_arn: "arn:aws:autoscaling:..."
    #=>      }
    #=>    ],
    #=>    next_token: nil
    #=>  }}
"""
@spec describe_scaling_activities(String.t(), keyword) :: {:ok, map} | {:error, term}
def describe_scaling_activities(auto_scaling_group_name, opts \\ [])
    when is_binary(auto_scaling_group_name) do
  if sandbox?(opts) do
    sandbox_describe_scaling_activities_response(auto_scaling_group_name, opts)
  else
    do_describe_scaling_activities(auto_scaling_group_name, opts)
  end
end

defp do_describe_scaling_activities(auto_scaling_group_name, opts) do
  params =
    flatten_query(%{
      "AutoScalingGroupName" => auto_scaling_group_name,
      "ActivityIds" => opts[:activity_ids],
      "IncludeDeletedGroups" => opts[:include_deleted_groups],
      "MaxRecords" => opts[:max_records],
      "NextToken" => opts[:next_token]
    })

  with {:ok, op} <- build_operation("DescribeScalingActivities", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_describe_scaling_activities(body)}
  end
end
```

Parser, next to `parse_describe_instance_refreshes/1`:

```elixir
@doc false
def parse_describe_scaling_activities_for_test(xml), do: parse_describe_scaling_activities(xml)

defp parse_describe_scaling_activities(body) do
  result =
    xpath(body, ~x"//DescribeScalingActivitiesResult"e,
      activities: [
        ~x"./Activities/member"l,
        activity_id: ~x"./ActivityId/text()"s,
        auto_scaling_group_name: ~x"./AutoScalingGroupName/text()"s,
        description: ~x"./Description/text()"os,
        cause: ~x"./Cause/text()"os,
        start_time: ~x"./StartTime/text()"os,
        end_time: ~x"./EndTime/text()"os,
        status_code: ~x"./StatusCode/text()"os,
        status_message: ~x"./StatusMessage/text()"os,
        progress: ~x"./Progress/text()"oi,
        details: ~x"./Details/text()"os,
        auto_scaling_group_state: ~x"./AutoScalingGroupState/text()"os,
        auto_scaling_group_arn: ~x"./AutoScalingGroupARN/text()"os
      ],
      next_token: ~x"./NextToken/text()"s
    )

  %{activities: result.activities, next_token: nilify(result.next_token)}
end
```

Sandbox wiring mirrors the `describe_instance_refreshes` pair in `lib/aws_sdk/auto_scaling/sandbox.ex` exactly, including its argument naming: `describe_scaling_activities_response(asg, opts)` with `AwsSdk.Sandbox.doc_examples([:asg])`, keyed off `asg`; delegate `sandbox_describe_scaling_activities_response(asg, opts)` (as `:describe_scaling_activities_response`) and `else`-stub `defp sandbox_describe_scaling_activities_response(_a, _o), do: raise(@sandbox_unavailable)` in `auto_scaling.ex` (the attribute already exists there).

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/auto_scaling.ex lib/aws_sdk/auto_scaling/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/auto_scaling/sandbox_test.exs
git commit -m "feat: AutoScaling DescribeScalingActivities"
```

---

### Task 16: ELBv2 `modify_listener`

**Files:**
- Modify: `lib/aws_sdk/elastic_load_balancing_v2.ex` (public fn next to `modify_rule`; extract `listener_fields/0` from `parse_describe_listeners/1`; add `parse_modify_listener/1`; update the `@moduledoc` line claiming "`modify_rule/3` is the only mutating operation"), `lib/aws_sdk/elastic_load_balancing_v2/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/elastic_load_balancing_v2/sandbox_test.exs`

**Interfaces:**
- Consumes: `build_operation/3`, `Client.request/1`, `flatten_query/1`, `nilify/1`, the existing listener xpath keyword list inside `parse_describe_listeners/1`.
- Produces: `AwsSdk.ElasticLoadBalancingV2.modify_listener(listener_arn :: String.t(), default_actions :: [map()], opts) :: {:ok, %{listeners: [map()]}} | {:error, term()}`; `parse_modify_listener/1` (`@doc false` public, like the module's other `parse_*`); `Sandbox.set_modify_listener_responses/1` keyed off `listener_arn`.

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "ModifyListener returns the listener with its new default actions" do
  xml = """
  <ModifyListenerResponse><ModifyListenerResult><Listeners><member>
  <ListenerArn>arn:listener/1</ListenerArn>
  <LoadBalancerArn>arn:lb/1</LoadBalancerArn>
  <Port>443</Port><Protocol>HTTPS</Protocol>
  <DefaultActions><member>
  <Type>fixed-response</Type>
  <FixedResponseConfig><StatusCode>503</StatusCode>
  <ContentType>text/plain</ContentType><MessageBody>maintenance</MessageBody>
  </FixedResponseConfig>
  </member></DefaultActions>
  </member></Listeners></ModifyListenerResult></ModifyListenerResponse>
  """

  parsed = AwsSdk.ElasticLoadBalancingV2.parse_modify_listener(xml)

  assert [listener] = parsed.listeners
  assert listener.listener_arn == "arn:listener/1"
  assert listener.port == 443
  assert [action] = listener.default_actions
  assert action.type == "fixed-response"
  assert action.fixed_response_config.status_code == "503"
  assert action.fixed_response_config.message_body == "maintenance"
end
```

Sandbox:

```elixir
describe "modify_listener/3" do
  test "keys off the listener arn" do
    Sandbox.set_modify_listener_responses([
      {"arn:listener/1",
       fn -> {:ok, %{listeners: [%{listener_arn: "arn:listener/1", port: 443}]}} end}
    ])

    assert {:ok, %{listeners: [%{listener_arn: "arn:listener/1"}]}} =
             ElasticLoadBalancingV2.modify_listener(
               "arn:listener/1",
               [%{type: "fixed-response", fixed_response_config: %{status_code: "503"}}],
               sandbox: [enabled: true]
             )
  end
end
```

Match the sandbox test file's existing alias for the module (open it first).

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

Public function, mirroring `modify_rule/3` (same guard rationale — an empty action list would be dropped by the encoder and silently no-op):

```elixir
@doc """
Modifies a listener's default actions.

The action encoding is identical to `modify_rule/3` — the deployd use is
resetting a listener's default action to a fixed-response 503 and back.
Any property not supplied keeps its current value.

## Arguments

  - `listener_arn` - the listener's ARN
  - `default_actions` - list of action maps (same shape `modify_rule/3` takes)

## Options

  - `:port`, `:protocol`, `:ssl_policy`, `:certificates` - other listener
    properties AWS allows modifying; passed through the same Query encoding

## Examples

    AwsSdk.ElasticLoadBalancingV2.modify_listener(
      "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/50dc6c/f2f7dc",
      [
        %{
          type: "fixed-response",
          fixed_response_config: %{status_code: "503", content_type: "text/plain", message_body: "maintenance"}
        }
      ]
    )
    #=> {:ok,
    #=>  %{
    #=>    listeners: [
    #=>      %{
    #=>        listener_arn: "arn:aws:elasticloadbalancing:...:listener/app/web/50dc6c/f2f7dc",
    #=>        load_balancer_arn: "arn:aws:elasticloadbalancing:...:loadbalancer/app/web/50dc6c",
    #=>        port: 443,
    #=>        protocol: "HTTPS",
    #=>        ssl_policy: "ELBSecurityPolicy-TLS13-1-2-2021-06",
    #=>        alpn_policy: [],
    #=>        certificates: [%{certificate_arn: "arn:aws:acm:..."}],
    #=>        mutual_authentication: %{mode: "off", ...},
    #=>        default_actions: [
    #=>          %{type: "fixed-response", fixed_response_config: %{status_code: "503", ...}, ...}
    #=>        ]
    #=>      }
    #=>    ]
    #=>  }}
"""
@spec modify_listener(listener_arn :: String.t(), default_actions :: [map()], opts :: keyword()) ::
        {:ok, map()} | {:error, term()}
def modify_listener(listener_arn, [_ | _] = default_actions, opts \\ [])
    when is_binary(listener_arn) do
  if sandbox?(opts) do
    sandbox_modify_listener_response(listener_arn, default_actions, opts)
  else
    do_modify_listener(listener_arn, default_actions, opts)
  end
end

defp do_modify_listener(listener_arn, default_actions, opts) do
  params =
    flatten_query(%{
      "ListenerArn" => listener_arn,
      "DefaultActions" => default_actions,
      "Port" => opts[:port],
      "Protocol" => opts[:protocol],
      "SslPolicy" => opts[:ssl_policy],
      "Certificates" => opts[:certificates]
    })

  with {:ok, op} <- build_operation("ModifyListener", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_modify_listener(body)}
  end
end
```

Refactor: in `parse_describe_listeners/1`, extract the listener keyword list (everything from `listener_arn:` through `default_actions:`) into a new private `listener_fields/0` (same extraction style as the existing `rule_fields/0`), so `parse_describe_listeners/1` becomes:

```elixir
@doc false
def parse_describe_listeners(body) do
  result =
    xpath(body, ~x"//DescribeListenersResult"e,
      listeners: [~x"./Listeners/member"l | listener_fields()],
      next_marker: ~x"./NextMarker/text()"s
    )

  %{listeners: result.listeners, next_marker: nilify(result.next_marker)}
end
```

with `listener_fields/0` holding the previously-inline keyword list verbatim (listener_arn, load_balancer_arn, port, protocol, ssl_policy, alpn_policy, certificates, mutual_authentication, default_actions — unchanged selectors). Then:

ELBv2's parsers are already `@doc false` public functions (`parse_describe_listeners/1` and friends), so — deviating from recipe B on purpose — no `parse_*_for_test` wrapper is added; the conformance test calls `parse_modify_listener/1` directly, matching the module:

```elixir
@doc false
def parse_modify_listener(body) do
  result =
    xpath(body, ~x"//ModifyListenerResult"e,
      listeners: [~x"./Listeners/member"l | listener_fields()]
    )

  %{listeners: result.listeners}
end
```

Sandbox wiring per recipe A in `lib/aws_sdk/elastic_load_balancing_v2/sandbox.ex`, mirroring the `modify_rule` pair — `modify_listener_response(listener_arn, default_actions, opts)` keyed off `listener_arn` with `examples = AwsSdk.Sandbox.doc_examples([:listener_arn, :default_actions])`, plus `set_modify_listener_responses/1`; delegate `sandbox_modify_listener_response(listener_arn, default_actions, opts)` / stub `(_l, _a, _o)` (match the module's existing stub naming style, e.g. `@sandbox_unavailable`).

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format` (the extraction must leave every existing `describe_listeners` test green).

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/elastic_load_balancing_v2.ex lib/aws_sdk/elastic_load_balancing_v2/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/elastic_load_balancing_v2/sandbox_test.exs
git commit -m "feat: ELBv2 ModifyListener"
```

---

### Task 17: IAM `get_instance_profile`

**Files:**
- Modify: `lib/aws_sdk/iam.ex` (new "Instance profiles" section), `lib/aws_sdk/iam/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/iam/sandbox_test.exs`

**Interfaces:**
- Consumes: IAM's `build_operation/3` + `Client.request/1` pipeline (mirror `do_get_role/2`'s structure exactly — open it first), the existing `parse_role/2` (called as `parse_role(body, selector)`).
- Produces: `AwsSdk.IAM.get_instance_profile(instance_profile_name :: String.t(), opts) :: {:ok, %{instance_profile: map()}} | {:error, term()}`; `parse_instance_profile_for_test/1`; `Sandbox.set_get_instance_profile_responses/1` keyed off the profile name.

- [ ] **Step 1: Write the failing tests**

Conformance:

```elixir
test "GetInstanceProfile keeps the profile identity and its roles" do
  xml = """
  <GetInstanceProfileResponse><GetInstanceProfileResult><InstanceProfile>
  <Path>/</Path>
  <InstanceProfileName>web</InstanceProfileName>
  <InstanceProfileId>AIPAEXAMPLE</InstanceProfileId>
  <Arn>arn:aws:iam::123456789012:instance-profile/web</Arn>
  <CreateDate>2026-01-01T00:00:00Z</CreateDate>
  <Roles><member>
  <RoleName>web-role</RoleName><RoleId>AROAEXAMPLE</RoleId>
  <Arn>arn:aws:iam::123456789012:role/web-role</Arn><Path>/</Path>
  <CreateDate>2026-01-01T00:00:00Z</CreateDate>
  </member></Roles>
  <Tags><member><Key>Team</Key><Value>ops</Value></member></Tags>
  </InstanceProfile></GetInstanceProfileResult></GetInstanceProfileResponse>
  """

  parsed = AwsSdk.IAM.parse_instance_profile_for_test(xml)

  profile = parsed.instance_profile
  assert profile.instance_profile_name == "web"
  assert profile.instance_profile_id == "AIPAEXAMPLE"
  assert profile.arn == "arn:aws:iam::123456789012:instance-profile/web"
  assert profile.create_date == "2026-01-01T00:00:00Z"
  assert [role] = profile.roles
  assert role.role_name == "web-role"
end
```

Sandbox:

```elixir
describe "get_instance_profile/2" do
  test "keys off the profile name" do
    Sandbox.set_get_instance_profile_responses([
      {"web", fn -> {:ok, %{instance_profile: %{instance_profile_name: "web", roles: []}}} end}
    ])

    assert {:ok, %{instance_profile: %{instance_profile_name: "web"}}} =
             IAM.get_instance_profile("web", sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

Public function (mirror the request-building of `do_get_role/2` in the same file — same `build_operation` + `Client.request` `with` pipeline, only the action name, param key, and parse function differ):

```elixir
@doc """
Retrieves information about the specified instance profile, including
its creation date and the roles associated with it.

## Examples

    AwsSdk.IAM.get_instance_profile("web")
    #=> {:ok,
    #=>  %{
    #=>    instance_profile: %{
    #=>      path: "/",
    #=>      instance_profile_name: "web",
    #=>      instance_profile_id: "AIPAEXAMPLE",
    #=>      arn: "arn:aws:iam::123456789012:instance-profile/web",
    #=>      create_date: "2026-01-01T00:00:00Z",
    #=>      roles: [
    #=>        %{role_name: "web-role", role_id: "AROAEXAMPLE", arn: "arn:aws:iam::123456789012:role/web-role", ...}
    #=>      ],
    #=>      tags: [%{key: "Team", value: "ops"}]
    #=>    }
    #=>  }}
"""
@spec get_instance_profile(instance_profile_name :: String.t(), opts :: keyword()) ::
        {:ok, %{instance_profile: map()}} | {:error, term()}
def get_instance_profile(instance_profile_name, opts \\ [])
    when is_binary(instance_profile_name) do
  if sandbox?(opts) do
    sandbox_get_instance_profile_response(instance_profile_name, opts)
  else
    do_get_instance_profile(instance_profile_name, opts)
  end
end
```

`do_get_instance_profile/2` (same shape as the post-refactor `do_get_role/2`):

```elixir
defp do_get_instance_profile(instance_profile_name, opts) do
  params = %{"InstanceProfileName" => instance_profile_name}

  with {:ok, op} <- build_operation("GetInstanceProfile", params, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, parse_instance_profile(body)}
  end
end
```

Parser — reuse `parse_role/2` for the nested roles:

```elixir
@doc false
def parse_instance_profile_for_test(xml), do: parse_instance_profile(xml)

defp parse_instance_profile(body) do
  %{
    instance_profile: %{
      path: xpath(body, ~x"//GetInstanceProfileResult/InstanceProfile/Path/text()"s),
      instance_profile_name:
        xpath(body, ~x"//GetInstanceProfileResult/InstanceProfile/InstanceProfileName/text()"s),
      instance_profile_id:
        xpath(body, ~x"//GetInstanceProfileResult/InstanceProfile/InstanceProfileId/text()"s),
      arn: xpath(body, ~x"//GetInstanceProfileResult/InstanceProfile/Arn/text()"s),
      create_date: xpath(body, ~x"//GetInstanceProfileResult/InstanceProfile/CreateDate/text()"s),
      roles: parse_role(body, ~x"//GetInstanceProfileResult/InstanceProfile/Roles/member"l),
      tags:
        xpath(body, ~x"//GetInstanceProfileResult/InstanceProfile/Tags/member"l,
          key: ~x"./Key/text()"s,
          value: ~x"./Value/text()"s
        )
    }
  }
end
```

(`parse_role/2` already returns a list when given an `l` selector — see its use in `list_roles`. Verify the tag member casing against IAM's existing tag parsing before committing; IAM uses PascalCase `Key`/`Value`.)

Sandbox wiring per recipe A in `lib/aws_sdk/iam/sandbox.ex`, keyed off `instance_profile_name`; delegate `sandbox_get_instance_profile_response(instance_profile_name, opts)` / stub `(_, _)` following the module's existing style.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/iam.ex lib/aws_sdk/iam/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/iam/sandbox_test.exs
git commit -m "feat: IAM GetInstanceProfile"
```

---

### Task 18: S3 `delete_objects`

**Files:**
- Modify: `lib/aws_sdk/s3.ex` (public fn next to `delete_object`), `lib/aws_sdk/s3/xml_builder.ex` (new `build_delete/2`; extend the `@moduledoc`'s operation list — it currently names only the three `Put*` operations — with `DeleteObjects`), `lib/aws_sdk/s3/xml_parser.ex` (new `parse_delete_result/1`), `lib/aws_sdk/s3/sandbox.ex`
- Test: `test/aws_sdk/conformance_test.exs`, `test/aws_sdk/s3/sandbox_test.exs` (no `xml_builder_test.exs` exists; the builder and parser assertions live in the conformance test)

**Interfaces:**
- Consumes: `build_operation/4`, `Client.request/1`, `put_opts/2`, `xml_body_headers/1` in `s3.ex`; SweetXml (already imported or aliased in `s3.ex` — check how `XMLParser` is used and follow; the parse function may live in `AwsSdk.S3.XMLParser` if that is where the module keeps body parsers — mirror `parse_complete_multipart`'s home).
- Produces: `AwsSdk.S3.delete_objects(bucket :: String.t(), objects :: [String.t() | map()], opts) :: {:ok, %{deleted: [map()], error: [map()]}} | {:error, term()}`; `AwsSdk.S3.XMLBuilder.build_delete(objects, quiet :: boolean())`; `AwsSdk.S3.XMLParser.parse_delete_result/1`; `Sandbox.set_delete_objects_responses/1` keyed off `bucket` (exact string or regex, like the other S3 setters).

- [ ] **Step 1: Write the failing tests**

Conformance (builder + parser are both pure):

```elixir
test "DeleteObjects body encodes keys, version ids, and quiet" do
  xml =
    AwsSdk.S3.XMLBuilder.build_delete(
      ["plain.txt", %{key: "reports/2026.csv", version_id: "v1"}],
      true
    )

  assert xml ==
           ~s(<Delete xmlns="http://s3.amazonaws.com/doc/2006-03-01/">) <>
             "<Object><Key>plain.txt</Key></Object>" <>
             "<Object><Key>reports/2026.csv</Key><VersionId>v1</VersionId></Object>" <>
             "<Quiet>true</Quiet>" <>
             "</Delete>"
end

test "DeleteObjects result keeps deleted entries and per-key errors" do
  xml = """
  <DeleteResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Deleted><Key>a.txt</Key></Deleted>
  <Deleted><Key>b.txt</Key><VersionId>v2</VersionId>
  <DeleteMarker>true</DeleteMarker><DeleteMarkerVersionId>dm1</DeleteMarkerVersionId></Deleted>
  <Error><Key>c.txt</Key><Code>AccessDenied</Code><Message>Access Denied</Message></Error>
  </DeleteResult>
  """

  parsed = AwsSdk.S3.XMLParser.parse_delete_result(xml)

  assert [a, b] = parsed.deleted
  assert a.key == "a.txt"
  assert b.version_id == "v2"
  assert b.delete_marker == true
  assert b.delete_marker_version_id == "dm1"
  assert [err] = parsed.error
  assert err.key == "c.txt"
  assert err.code == "AccessDenied"
  assert err.message == "Access Denied"
end
```

Sandbox:

```elixir
describe "delete_objects/3" do
  test "keys off the bucket" do
    Sandbox.set_delete_objects_responses([
      {"my-bucket", fn -> {:ok, %{deleted: [%{key: "a.txt"}], error: []}} end}
    ])

    assert {:ok, %{deleted: [%{key: "a.txt"}], error: []}} =
             S3.delete_objects("my-bucket", ["a.txt"], sandbox: [enabled: true])
  end
end
```

- [ ] **Step 2: Run to verify failure** — expected FAIL on undefined functions.

- [ ] **Step 3: Implement**

In `lib/aws_sdk/s3/xml_builder.ex` (docs/examples in the module's existing style):

```elixir
@doc """
Builds the `<Delete>` XML body for `DeleteObjects`.

Each object is a key binary or a `%{key: key, version_id: version_id}`
map. `quiet` asks S3 to omit per-key success entries from the response.

## Examples

    AwsSdk.S3.XMLBuilder.build_delete(["a.txt", %{key: "b.txt", version_id: "v1"}], false)
    #=> ~s(<Delete xmlns="http://s3.amazonaws.com/doc/2006-03-01/">) <>
    #=>   "<Object><Key>a.txt</Key></Object>" <>
    #=>   "<Object><Key>b.txt</Key><VersionId>v1</VersionId></Object>" <>
    #=>   "</Delete>"
"""
@spec build_delete(objects :: [String.t() | map()], quiet :: boolean()) :: binary()
def build_delete(objects, quiet) when is_list(objects) and is_boolean(quiet) do
  objects_xml = Enum.map_join(objects, &delete_object_xml/1)
  quiet_xml = if quiet, do: "<Quiet>true</Quiet>", else: ""

  "<Delete xmlns=\"#{@xmlns}\">#{objects_xml}#{quiet_xml}</Delete>"
end

defp delete_object_xml(key) when is_binary(key) do
  "<Object><Key>#{key}</Key></Object>"
end

defp delete_object_xml(%{key: key} = object) do
  version_xml =
    case object[:version_id] do
      nil -> ""
      version_id -> "<VersionId>#{version_id}</VersionId>"
    end

  "<Object><Key>#{key}</Key>#{version_xml}</Object>"
end
```

(Values are interpolated raw, exactly as every other builder in this module does — `build_public_access_block`, `build_bucket_encryption`, and `build_lifecycle_configuration` all interpolate without escaping.)

In `lib/aws_sdk/s3/xml_parser.ex`, following that module's existing SweetXml style (open it and match how `parse_complete_multipart/1` anchors and coerces):

```elixir
@doc """
Parses the `<DeleteResult>` body a `DeleteObjects` call returns.
"""
@spec parse_delete_result(binary()) :: %{deleted: [map()], error: [map()]}
def parse_delete_result(xml) do
  deleted =
    xml
    |> xpath(~x"//DeleteResult/Deleted"l,
      key: ~x"./Key/text()"s,
      version_id: ~x"./VersionId/text()"so,
      delete_marker: ~x"./DeleteMarker/text()"so,
      delete_marker_version_id: ~x"./DeleteMarkerVersionId/text()"so
    )
    |> Enum.map(fn entry -> %{entry | delete_marker: to_bool(entry.delete_marker)} end)

  %{
    deleted: deleted,
    error:
      xpath(xml, ~x"//DeleteResult/Error"l,
        key: ~x"./Key/text()"s,
        version_id: ~x"./VersionId/text()"so,
        code: ~x"./Code/text()"so,
        message: ~x"./Message/text()"so
      )
  }
end
```

Coercion reuses the module's existing `to_bool/1` (the same helper `IsTruncated` goes through) and the optional-string modifier is written `so`, matching this module's existing selectors — do not add a new boolean helper here. `to_bool/1` maps an absent `DeleteMarker` to `false`.

In `lib/aws_sdk/s3.ex`, next to `delete_object/3`:

```elixir
@doc """
Deletes up to 1000 objects from a bucket in a single request.

S3 reports per-key outcomes in the body — a 200 response can still carry
per-key failures, so check `:error` before treating the batch as done.

## Arguments

  * `bucket` - The bucket name.
  * `objects` - List of keys (binaries) and/or `%{key:, version_id:}` maps.
  * `opts` - Options:
    * `:quiet` - Boolean; ask S3 to omit per-key success entries.

## Examples

    AwsSdk.S3.delete_objects("my-bucket", ["a.txt", %{key: "b.txt", version_id: "v1"}])
    #=> {:ok,
    #=>  %{
    #=>    deleted: [
    #=>      %{key: "a.txt", version_id: nil, delete_marker: false, delete_marker_version_id: nil},
    #=>      %{key: "b.txt", version_id: "v1", delete_marker: false, delete_marker_version_id: nil}
    #=>    ],
    #=>    error: []
    #=>  }}
"""
@spec delete_objects(bucket :: String.t(), objects :: [String.t() | map()], opts :: keyword()) ::
        {:ok, %{deleted: [map()], error: [map()]}} | {:error, term()}
def delete_objects(bucket, [_ | _] = objects, opts \\ []) when is_binary(bucket) do
  if sandbox?(opts) do
    sandbox_delete_objects_response(bucket, objects, opts)
  else
    do_delete_objects(bucket, objects, opts)
  end
end

defp do_delete_objects(bucket, objects, opts) do
  xml = XMLBuilder.build_delete(objects, opts[:quiet] || false)
  headers = xml_body_headers(xml)
  request_opts = put_opts(opts, query: %{"delete" => ""}, body: xml, headers: headers)

  with {:ok, op} <- build_operation(:post, bucket, nil, request_opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, XMLParser.parse_delete_result(body)}
  end
end
```

(S3 requires `Content-MD5` on `DeleteObjects`; `xml_body_headers/1` already supplies it.)

Sandbox wiring per recipe A in `lib/aws_sdk/s3/sandbox.ex`, mirroring the `delete_object` pair — `delete_objects_response(bucket, objects, opts)` keyed off `bucket` with `examples = AwsSdk.Sandbox.doc_examples([:bucket, :objects])`; delegate `sandbox_delete_objects_response(bucket, objects, opts)` in `s3.ex`. The `else`-branch stub follows S3's own style — a full function raising a heredoc (mirror `sandbox_delete_object_response`'s stub):

```elixir
defp sandbox_delete_objects_response(bucket, objects, opts) do
  raise """
  Cannot use sandbox mode outside of test environment.

  bucket: #{inspect(bucket)}
  objects: #{inspect(objects)}
  options: #{inspect(opts)}
  """
end
```

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/s3.ex lib/aws_sdk/s3/xml_builder.ex lib/aws_sdk/s3/xml_parser.ex lib/aws_sdk/s3/sandbox.ex test/aws_sdk/conformance_test.exs test/aws_sdk/s3/sandbox_test.exs
git commit -m "feat: S3 DeleteObjects batch delete"
```

---

### Task 19: Retire NEXT.md

**Files:**
- Delete: `NEXT.md`

**Interfaces:**
- Consumes: every operation from Tasks 1–18 existing and tested.
- Produces: nothing — cleanup.

- [ ] **Step 1: Confirm every NEXT.md row is implemented**

Run: `mix test`
Expected: PASS. Cross-check each operation in NEXT.md's tables against the public functions now exported (`grep -n "def send_command\|def get_command_invocation\|def list_command_invocations" lib/aws_sdk/ssm.ex` and equivalents per module). Every row, including the two formerly-optional ones, must exist.

This is a standalone 19th commit, one past the spec's 18-item list — the spec's commit plan records it as its own final entry.

- [ ] **Step 2: Delete and commit**

```bash
git rm NEXT.md
git commit -m "chore: retire NEXT.md — every operation on it is implemented"
```
