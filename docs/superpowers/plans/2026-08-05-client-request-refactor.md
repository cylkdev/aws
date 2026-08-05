# Client.request Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire the per-module `perform`/`deserialize_response` helpers: error mapping moves verbatim into `AwsSdk.Client.request/1`, and every operation's `do_*` function becomes an explicit `with` pipeline.

**Architecture:** `Client.request/1` wraps the existing `Client.execute/1` and maps `{:error, {:http_error, status, body}}` / `{:error, reason}` to `ErrorMessage` errors (3xx → `bad_request`, 4xx → `not_found`, 5xx → `service_unavailable`, transport → `internal_server_error`); success passes the response map through untouched. Then each of the eleven service modules is migrated in its own commit: delete its `perform`/`deserialize_response` (and JSON modules' `decode_response`; S3's `s3_request`/`normalize_notification_error`), rewrite every call site to `with {:ok, op} <- build_operation(...), {:ok, %{body: body}} <- Client.request(op) do ...`.

**Tech Stack:** Elixir, `ErrorMessage` library, ExUnit. Spec: `docs/superpowers/specs/2026-08-05-client-request-refactor-design.md`.

## Global Constraints

- `mix compile` is warnings-as-errors outside test; `mix compile && mix test && mix format` must be clean before every commit. This is a behavior-preserving refactor — the existing suite is the regression guard, and **no existing test may be edited to make a module's migration pass** (a failing test means the rewrite changed behavior; fix the rewrite).
- One commit per task. Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- **The `with`-pipeline shapes shown in the tasks are the only new shapes.** Do not invent additional helpers, wrappers, or macros. Params-building code, parsers, `build_operation`, `sandbox?/1` branches, Sandbox modules, `maybe_put`, `decode_body`, and `deserialize_opts` are untouched everywhere.
- **Result-normalization rule (applies at every rewritten call site):** the old `deserialize_response` success clause passed `{:ok, _}`/`{:error, _}` callback results through and wrapped anything else in `{:ok, _}`. Preserve that by hand when moving a callback body into a `with` block: a bare-value expression (e.g. `Serializer.deserialize(...)`, `parse_x(body)`, `deserialize_headers(...)`) gets an explicit `{:ok, ...}` wrap; an expression already returning a result tuple (e.g. `XMLParser.parse_complete_multipart(body)` returning `{:ok, _} | {:error, _}`) is left as the `with`-block's last expression unchanged. When unsure which kind a callback is, read its definition — never guess.
- Direct `Client.execute/1` call sites that are *not* `perform`/`s3_request` (e.g. `lib/aws_sdk/sts.ex:159`, `lib/aws_sdk/credentials/sso.ex`) are out of scope — leave them alone.
- Sandbox tests and conformance tests exercise none of this plumbing; the tests that matter per module are that module's full test file plus the whole suite.

### The uniform call-site transformation

Every migration task applies this same mechanical rewrite, so it is stated once. Old tail (JSON modules — SSM shown; EventBridge/Logs/IdentityCenter/Organizations identical):

```elixir
perform("GetParameter", data, opts)
|> deserialize_response(opts, fn body ->
  Serializer.deserialize(body, deserialize_opts(opts))
end)
```

New tail:

```elixir
with {:ok, op} <- build_operation("GetParameter", data, opts),
     {:ok, %{body: body}} <- Client.request(op) do
  {:ok, Serializer.deserialize(decode_body(body), deserialize_opts(opts))}
end
```

Note the two composed changes: `decode_body/1` (previously applied inside `decode_response/1`) now wraps `body` explicitly, and the bare `Serializer.deserialize` result gets the `{:ok, ...}` wrap per the normalization rule.

Old tail (Query/XML modules — EC2 shown; IAM/STS identical, AutoScaling/ELBv2 differ only in passing `&parse_x/1` instead of an anonymous fn):

```elixir
"DescribeLaunchTemplates"
|> perform(params, opts)
|> deserialize_response(opts, fn body -> {:ok, parse_describe_launch_templates(body)} end)
```

New tail:

```elixir
with {:ok, op} <- build_operation("DescribeLaunchTemplates", params, opts),
     {:ok, %{body: body}} <- Client.request(op) do
  {:ok, parse_describe_launch_templates(body)}
end
```

(The Query modules' `perform` already unwrapped `%{body: body}` — that match moves into the `with` clause.)

Per module, after rewriting all call sites, delete: `defp perform`, every `defp deserialize_response` clause, and (JSON modules only) `defp decode_response` — `decode_body/1` stays. Find every call site with:

```bash
grep -n "deserialize_response(" lib/aws_sdk/<module>.ex
```

and confirm zero remain before compiling.

---

### Task 1: `AwsSdk.Client.request/1`

**Files:**
- Modify: `lib/aws_sdk/client.ex` (new public function after `execute/1`)
- Create: `test/aws_sdk/client_test.exs`

**Interfaces:**
- Consumes: existing `AwsSdk.Client.execute/1` (returns `{:ok, %{status_code:, headers:, body: ...}}` from `translate_buffered/1` | `{:error, {:http_error, status, body}}` | `{:error, reason}`).
- Produces: `AwsSdk.Client.request(op :: struct) :: {:ok, map} | {:error, ErrorMessage.t()}` — the seam every migration task (2–12) rewrites onto. Also `AwsSdk.Client.map_response_for_test/1` (`@doc false`, the codebase's existing `*_for_test` convention) so the mapping is testable without HTTP.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule AwsSdk.ClientTest do
  use ExUnit.Case, async: true

  alias AwsSdk.Client

  describe "request/1 response mapping" do
    test "success passes the response map through untouched" do
      response = %{status_code: 200, headers: [{"etag", "x"}], body: "<ok/>"}

      assert Client.map_response_for_test({:ok, response}) == {:ok, response}
    end

    test "3xx maps to bad_request" do
      assert Client.map_response_for_test({:error, {:http_error, 301, "moved"}}) ==
               {:error, ErrorMessage.bad_request("redirect not followed.", %{response: "moved"})}
    end

    test "4xx maps to not_found" do
      assert Client.map_response_for_test({:error, {:http_error, 404, "nope"}}) ==
               {:error, ErrorMessage.not_found("resource not found.", %{response: "nope"})}
    end

    test "5xx maps to service_unavailable" do
      assert Client.map_response_for_test({:error, {:http_error, 503, "down"}}) ==
               {:error,
                ErrorMessage.service_unavailable("service temporarily unavailable", %{
                  response: "down"
                })}
    end

    test "transport errors map to internal_server_error" do
      assert Client.map_response_for_test({:error, :timeout}) ==
               {:error,
                ErrorMessage.internal_server_error("internal server error", %{reason: :timeout})}
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/aws_sdk/client_test.exs`
Expected: FAIL — `map_response_for_test/1` undefined.

- [ ] **Step 3: Implement**

In `lib/aws_sdk/client.ex`, directly after `execute/1`:

```elixir
@doc """
Executes a signed operation and maps failures to `ErrorMessage` errors.

This is the library's single status-code contract — 3xx →
`bad_request`, 4xx → `not_found`, 5xx → `service_unavailable`, transport
errors → `internal_server_error` — moved verbatim from the per-service
`deserialize_response/3` helpers it replaces. Success passes
`execute/1`'s response map (`:status_code`, `:headers`, `:body`, and the
streaming variants) through untouched.
"""
@spec request(struct) :: {:ok, map} | {:error, ErrorMessage.t()}
def request(%_{} = op) do
  op
  |> execute()
  |> map_response()
end

@doc false
def map_response_for_test(result), do: map_response(result)

defp map_response({:ok, response}), do: {:ok, response}

defp map_response({:error, {:http_error, status_code, response}})
     when status_code in 300..399 do
  {:error, ErrorMessage.bad_request("redirect not followed.", %{response: response})}
end

defp map_response({:error, {:http_error, status_code, response}})
     when status_code in 400..499 do
  {:error, ErrorMessage.not_found("resource not found.", %{response: response})}
end

defp map_response({:error, {:http_error, status_code, response}}) when status_code >= 500 do
  {:error,
   ErrorMessage.service_unavailable("service temporarily unavailable", %{response: response})}
end

defp map_response({:error, reason}) do
  {:error, ErrorMessage.internal_server_error("internal server error", %{reason: reason})}
end
```

The message strings and detail maps are byte-for-byte the ones in the existing `deserialize_response` clauses (e.g. `lib/aws_sdk/ssm.ex:637-650`, `lib/aws_sdk/s3.ex:3385-3403`) — do not "improve" them; equality-based tests and callers depend on them.

- [ ] **Step 4: Run to verify pass**

Run: `mix compile && mix test test/aws_sdk/client_test.exs && mix test`
Expected: all PASS (nothing calls `request/1` yet — additive).

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/client.ex test/aws_sdk/client_test.exs
git commit -m "feat: add Client.request/1 - the single HTTP-status-to-error contract"
```

---

### Task 2: Migrate `AwsSdk.SSM`

**Files:**
- Modify: `lib/aws_sdk/ssm.ex` (8 `do_*` functions; delete `perform/3` at ~503, `decode_response/1`+ its clauses at ~514-519, all `deserialize_response/3` clauses at ~629-650; `decode_body/1`, `decode_body("")`, `deserialize_opts/1`, `maybe_put/2,3` stay)
- Test: existing `test/aws_sdk/ssm/` suite (no new tests — behavior-preserving)

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1` from Task 1; existing `build_operation/3` in `ssm.ex`.
- Produces: `ssm.ex` with zero `perform`/`deserialize_response`/`decode_response` references — the template the other JSON modules (Tasks 3–6) copy.

- [ ] **Step 1: Baseline**

Run: `mix test` — must be green before touching anything.

- [ ] **Step 2: Rewrite every call site**

Apply the JSON transformation from Global Constraints to all 8 `do_*` functions (`do_get_parameter`, `do_get_parameters`, `do_get_parameters_by_path`, `do_put_parameter`, `do_delete_parameter`, `do_delete_parameters`, `do_describe_parameters`, `do_describe_instance_information`). Worked example — `do_get_parameter/2` becomes:

```elixir
defp do_get_parameter(name, opts) do
  data =
    %{"Name" => name}
    |> maybe_put("WithDecryption", opts[:with_decryption])

  with {:ok, op} <- build_operation("GetParameter", data, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, Serializer.deserialize(decode_body(body), deserialize_opts(opts))}
  end
end
```

Every SSM callback is the same `Serializer.deserialize(body, deserialize_opts(opts))` shape, so all 8 rewrites are this pattern with their own action string and data map (which are untouched).

- [ ] **Step 3: Delete the helpers**

Delete `defp perform/3`, all `defp decode_response/1` clauses, and all `defp deserialize_response/3` clauses. Keep `decode_body/1` (both clauses) — the success path now calls it directly. Confirm `grep -n "deserialize_response(\|decode_response(\|perform(" lib/aws_sdk/ssm.ex` shows zero call sites.

- [ ] **Step 4: Verify**

Run: `mix compile && mix test && mix format`
Expected: clean compile (an unused `decode_body` or `deserialize_opts` would fail warnings-as-errors — that means a call site was rewritten wrong, not that the helper should be deleted), full suite green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ssm.ex
git commit -m "refactor: SSM ops call Client.request through explicit with-pipelines"
```

---

### Task 3: Migrate `AwsSdk.EventBridge`

**Files:**
- Modify: `lib/aws_sdk/event_bridge.ex` (all `deserialize_response` call sites — `grep -c` reports 28 occurrences including definitions; delete `perform/3` at ~1209, `decode_response/1` at ~1220-1225, `deserialize_response/3` clauses at ~1480-1502)
- Test: existing `test/aws_sdk/event_bridge/` suite

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1`; the module's own `build_operation/3`.
- Produces: `event_bridge.ex` free of the helpers.

- [ ] **Step 1: Baseline** — `mix test` green.

- [ ] **Step 2: Rewrite every call site**

Same JSON transformation as Task 2's worked example: each `do_*`'s tail

```elixir
perform("PutEvents", data, opts)
|> deserialize_response(opts, fn body -> ... end)
```

becomes

```elixir
with {:ok, op} <- build_operation("PutEvents", data, opts),
     {:ok, %{body: body}} <- Client.request(op) do
  ...  # old callback body, with `body` replaced by `decode_body(body)`
       # and bare results wrapped {:ok, ...} per the normalization rule
end
```

Most EventBridge callbacks are `Serializer.deserialize(body, deserialize_opts(opts))` → `{:ok, Serializer.deserialize(decode_body(body), deserialize_opts(opts))}`. For any callback that is not, read it and apply the normalization rule — do not force-fit; the callback body moves verbatim except for the `decode_body` substitution and the wrap.

- [ ] **Step 3: Delete the helpers** — `perform/3`, `decode_response/1`, `deserialize_response/3`; keep `decode_body/1`. Zero remaining references via grep.

- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.

- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/event_bridge.ex
git commit -m "refactor: EventBridge ops call Client.request through explicit with-pipelines"
```

---

### Task 4: Migrate `AwsSdk.Logs`

**Files:**
- Modify: `lib/aws_sdk/logs.ex` (helpers at ~768 `perform/3`, ~779-784 `decode_response/1`, ~985-1007 `deserialize_response/3`)
- Test: existing `test/aws_sdk/logs/` suite

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1`; the module's own `build_operation/3`.
- Produces: `logs.ex` free of the helpers.

- [ ] **Step 1: Baseline** — `mix test` green.
- [ ] **Step 2: Rewrite every call site** — identical transformation and normalization rule as Task 3 Step 2 (Logs is the same JSON 1.1 shape as SSM/EventBridge; Task 2's `do_get_parameter` example is the pattern). Read any non-`Serializer` callback before moving it.
- [ ] **Step 3: Delete the helpers** — `perform/3`, `decode_response/1`, `deserialize_response/3`; keep `decode_body/1`. Grep-confirm zero references.
- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.
- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/logs.ex
git commit -m "refactor: Logs ops call Client.request through explicit with-pipelines"
```

---

### Task 5: Migrate `AwsSdk.IdentityCenter`

**Files:**
- Modify: `lib/aws_sdk/identity_center.ex` (helpers: `perform/4` at ~1527 — note the extra `subservice` argument — `decode_response/1` at ~1560-1565, `deserialize_response/3` at ~1865-1887)
- Test: existing `test/aws_sdk/identity_center/` suite

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1`; the module's own `build_operation/4` (`build_operation(:sso | :identitystore, action, data, opts)` — see definitions at ~1505/~1516).
- Produces: `identity_center.ex` free of the helpers.

- [ ] **Step 1: Baseline** — `mix test` green.

- [ ] **Step 2: Rewrite every call site**

Same JSON transformation, with the four-argument `build_operation`:

```elixir
with {:ok, op} <- build_operation(:sso, "ListInstances", data, opts),
     {:ok, %{body: body}} <- Client.request(op) do
  {:ok, Serializer.deserialize(decode_body(body), deserialize_opts(opts))}
end
```

Each call site keeps whichever subservice atom its `perform(subservice, action, data, opts)` call passed today. This module has custom callbacks (e.g. the one that JSON-decodes `inline_policy`) — move each callback body verbatim into the `with` block with the `decode_body(body)` substitution and the normalization rule; read every callback before moving it.

- [ ] **Step 3: Delete the helpers** — `perform/4`, `decode_response/1`, `deserialize_response/3`; keep `decode_body/1`. Grep-confirm zero references.
- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.
- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/identity_center.ex
git commit -m "refactor: IdentityCenter ops call Client.request through explicit with-pipelines"
```

---

### Task 6: Migrate `AwsSdk.Organizations`

**Files:**
- Modify: `lib/aws_sdk/organizations.ex` (helpers at ~1210 `perform/3`, ~1221-1226 `decode_response/1`, ~1440-1462 `deserialize_response/3`)
- Test: existing `test/aws_sdk/organizations/` suite

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1`; the module's own `build_operation/3`.
- Produces: `organizations.ex` free of the helpers.

- [ ] **Step 1: Baseline** — `mix test` green.
- [ ] **Step 2: Rewrite every call site** — identical transformation as Task 3 Step 2 (same JSON 1.1 shape; Task 2's worked example is the pattern; read non-`Serializer` callbacks before moving them).
- [ ] **Step 3: Delete the helpers** — `perform/3`, `decode_response/1`, `deserialize_response/3`; keep `decode_body/1`. Grep-confirm zero references.
- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.
- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/organizations.ex
git commit -m "refactor: Organizations ops call Client.request through explicit with-pipelines"
```

---

### Task 7: Migrate `AwsSdk.EC2`

**Files:**
- Modify: `lib/aws_sdk/ec2.ex` (14 call sites; delete `perform/3` at ~1873-1881 and `deserialize_response/3` clauses at ~2123-2145)
- Test: existing `test/aws_sdk/ec2/` suite + `test/aws_sdk/conformance_test.exs`

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1`; the module's own `build_operation/3`.
- Produces: `ec2.ex` free of the helpers — the Query/XML template Tasks 8–11 copy.

- [ ] **Step 1: Baseline** — `mix test` green.

- [ ] **Step 2: Rewrite every call site**

Apply the Query/XML transformation from Global Constraints. Worked example — `do_describe_launch_templates/1`'s tail

```elixir
"DescribeLaunchTemplates"
|> perform(params, opts)
|> deserialize_response(opts, fn body -> {:ok, parse_describe_launch_templates(body)} end)
```

becomes

```elixir
with {:ok, op} <- build_operation("DescribeLaunchTemplates", params, opts),
     {:ok, %{body: body}} <- Client.request(op) do
  {:ok, parse_describe_launch_templates(body)}
end
```

EC2's callbacks already return `{:ok, ...}` tuples (`fn body -> {:ok, parse_x(body)} end`) or build maps inline (`describe_vpcs` parses inside the callback) — the callback body moves into the `with` block unchanged; only the `perform`/`deserialize_response` scaffolding around it goes away.

- [ ] **Step 3: Delete the helpers** — `perform/3` and all `deserialize_response/3` clauses. Grep-confirm zero references.
- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.
- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/ec2.ex
git commit -m "refactor: EC2 ops call Client.request through explicit with-pipelines"
```

---

### Task 8: Migrate `AwsSdk.IAM`

**Files:**
- Modify: `lib/aws_sdk/iam.ex` (largest module — 46 call sites; delete `perform/3` at ~2314-2322 and `deserialize_response/3` clauses at ~2780-2803)
- Test: existing `test/aws_sdk/iam/` suite + conformance tests

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1`; the module's own `build_operation/3`.
- Produces: `iam.ex` free of the helpers.

- [ ] **Step 1: Baseline** — `mix test` green.
- [ ] **Step 2: Rewrite every call site** — the Query/XML transformation exactly as Task 7 Step 2's worked example, one `do_*` at a time (IAM's `perform` has the same `{:ok, %{body: body}} -> {:ok, body}` unwrap as EC2's, so the `with` clause `{:ok, %{body: body}} <- Client.request(op)` is the drop-in). IAM callbacks mix `{:ok, ...}`-returning fns and bare-map fns — apply the normalization rule per site, reading each callback before moving it. With 46 sites, work top-to-bottom and re-run `mix compile` every ~10 sites to catch mistakes early.
- [ ] **Step 3: Delete the helpers** — grep-confirm zero references.
- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.
- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/iam.ex
git commit -m "refactor: IAM ops call Client.request through explicit with-pipelines"
```

---

### Task 9: Migrate `AwsSdk.STS`

**Files:**
- Modify: `lib/aws_sdk/sts.ex` (1 call site; delete `perform/3` at ~277-285 and `deserialize_response/3` clauses at ~335-358). The direct `Client.execute` call at `lib/aws_sdk/sts.ex:159` is NOT a `perform` site — leave it untouched.
- Test: existing `test/aws_sdk/sts/` suite (the `AssumeRole` credentials provider routes through `AwsSdk.STS.assume_role/4`, so credential-chain tests also cover this)

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1`; the module's own `build_operation/3`.
- Produces: `sts.ex` free of the helpers.

- [ ] **Step 1: Baseline** — `mix test` green.
- [ ] **Step 2: Rewrite every call site** — the Query/XML transformation exactly as Task 7 Step 2's worked example (STS's `perform` is byte-identical to EC2's).
- [ ] **Step 3: Delete the helpers** — grep-confirm zero references (`:159`'s `Client.execute` remains, by design).
- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.
- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/sts.ex
git commit -m "refactor: STS ops call Client.request through explicit with-pipelines"
```

---

### Task 10: Migrate `AwsSdk.AutoScaling`

**Files:**
- Modify: `lib/aws_sdk/auto_scaling.ex` (11 call sites; delete `perform/3` at ~731-739 and `deserialize_response/3` clauses at ~1241-1263)
- Test: existing `test/aws_sdk/auto_scaling/` suite + conformance tests

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1`; the module's own `build_operation/3`.
- Produces: `auto_scaling.ex` free of the helpers.

- [ ] **Step 1: Baseline** — `mix test` green.

- [ ] **Step 2: Rewrite every call site**

Same Query/XML transformation; AutoScaling passes captured parsers (`&parse_describe_instance_refreshes/1`) whose results are bare maps, so the wrap is explicit. Worked example — `do_describe_instance_refreshes/2`'s tail

```elixir
"DescribeInstanceRefreshes"
|> perform(params, opts)
|> deserialize_response(opts, &parse_describe_instance_refreshes/1)
```

becomes

```elixir
with {:ok, op} <- build_operation("DescribeInstanceRefreshes", params, opts),
     {:ok, %{body: body}} <- Client.request(op) do
  {:ok, parse_describe_instance_refreshes(body)}
end
```

(Check each captured parser: those already returning `{:ok, _}` keep their tuple and get no extra wrap.)

- [ ] **Step 3: Delete the helpers** — grep-confirm zero references.
- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.
- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/auto_scaling.ex
git commit -m "refactor: AutoScaling ops call Client.request through explicit with-pipelines"
```

---

### Task 11: Migrate `AwsSdk.ElasticLoadBalancingV2`

**Files:**
- Modify: `lib/aws_sdk/elastic_load_balancing_v2.ex` (6 call sites; delete `perform/3` at ~749-757 and `deserialize_response/3` clauses at ~1262-1284)
- Test: existing `test/aws_sdk/elastic_load_balancing_v2/` suite + conformance tests

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1`; the module's own `build_operation/3`.
- Produces: `elastic_load_balancing_v2.ex` free of the helpers.

- [ ] **Step 1: Baseline** — `mix test` green.
- [ ] **Step 2: Rewrite every call site** — exactly as Task 10 Step 2's worked example (ELBv2 also passes captured bare-map parsers like `&parse_describe_listeners/1`; wrap each result `{:ok, parse_x(body)}`).
- [ ] **Step 3: Delete the helpers** — grep-confirm zero references.
- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.
- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/elastic_load_balancing_v2.ex
git commit -m "refactor: ELBv2 ops call Client.request through explicit with-pipelines"
```

---

### Task 12: Migrate `AwsSdk.S3`

**Files:**
- Modify: `lib/aws_sdk/s3.ex` (17 call sites; delete `s3_request/4` at ~2582-2586, `normalize_notification_error/2` clauses, and `deserialize_response/3` clauses at ~3377-3403)
- Test: existing `test/aws_sdk/s3/` suite + conformance tests

**Interfaces:**
- Consumes: `AwsSdk.Client.request/1`; the module's own `build_operation/4` (`build_operation(method, bucket, key, opts)`).
- Produces: `s3.ex` free of `s3_request`, `deserialize_response`, and `normalize_notification_error`.

- [ ] **Step 1: Baseline** — `mix test` green.

- [ ] **Step 2: Rewrite every call site**

The S3 transformation: `s3_request(method, bucket, key, request_opts) |> deserialize_response(opts, fn <pattern> -> ... end)` becomes

```elixir
with {:ok, op} <- build_operation(method, bucket, key, request_opts),
     {:ok, <pattern>} <- Client.request(op) do
  ...  # old callback body, normalization rule applied
end
```

where `<pattern>` is whatever the old callback matched — `%{body: body}`, `%{headers: headers}`, or a whole-response binding. Three worked examples covering the variants:

`put_bucket_config/4` (headers callback, bare-map `deserialize_headers` result):

```elixir
defp put_bucket_config(bucket, query_key, xml, opts) do
  headers = xml_body_headers(xml)
  request_opts = put_opts(opts, query: %{query_key => ""}, body: xml, headers: headers)

  with {:ok, op} <- build_operation(:put, bucket, nil, request_opts),
       {:ok, %{headers: response_headers}} <- Client.request(op) do
    {:ok, deserialize_headers(response_headers, opts)}
  end
end
```

(Before committing this one, read `deserialize_headers/2` — if it already returns `{:ok, _}`, drop the wrap per the normalization rule.)

`do_complete_multipart_upload/5` (tuple-returning parser — no wrap):

```elixir
:post
|> s3_request(bucket, key, put_opts(opts, query: query, body: xml, headers: headers))
|> deserialize_response(opts, &deserialize_completed_multipart(&1, bucket, key, upload_id, opts))
```

becomes

```elixir
with {:ok, op} <- build_operation(:post, bucket, key, put_opts(opts, query: query, body: xml, headers: headers)),
     {:ok, response} <- Client.request(op) do
  deserialize_completed_multipart(response, bucket, key, upload_id, opts)
end
```

(`deserialize_completed_multipart` returns `XMLParser.parse_complete_multipart/1`'s result tuple — left unwrapped.)

`get_raw_notification_xml/2` (direct `s3_request` site that fed `normalize_notification_error`):

```elixir
defp get_raw_notification_xml(bucket, opts) do
  with {:ok, op} <- build_operation(:get, bucket, nil, Keyword.put(opts, :query, %{"notification" => ""})),
       {:ok, %{body: body}} <- Client.request(op) do
    {:ok, body}
  end
end
```

`Client.request/1` already produces exactly the `ErrorMessage` errors `normalize_notification_error/2` was hand-building, so that helper and its call site disappear (delete the helper; the `with` returns the error unchanged). Streaming ops (`get_object` with `stream_response`, `stream_upload` paths) bind the whole response map — their callbacks move per the same rule; read each before moving.

- [ ] **Step 3: Delete the helpers** — `s3_request/4`, all `deserialize_response/3` clauses, all `normalize_notification_error/2` clauses. Grep-confirm zero references to all three.
- [ ] **Step 4: Verify** — `mix compile && mix test && mix format`, all clean/green.
- [ ] **Step 5: Commit**

```bash
git add lib/aws_sdk/s3.ex
git commit -m "refactor: S3 ops call Client.request through explicit with-pipelines"
```

---

### Task 13: Update CLAUDE.md and the NEXT.md operations plan

**Files:**
- Modify: `CLAUDE.md` (architecture bullet + error-handling section)
- Modify: `docs/superpowers/plans/2026-08-05-nextmd-operations.md` (every task's implementation tail)

**Interfaces:**
- Consumes: the migrated codebase from Tasks 1–12.
- Produces: documentation that matches the code, and a NEXT.md backlog plan whose code is written in the new style.

- [ ] **Step 1: Update CLAUDE.md**

In the service-modules architecture section, replace:

> Otherwise call `do_*` private functions that dispatch through the service's `Client` module, then pipe through `deserialize_response/3`

with:

> Otherwise call `do_*` private functions, each an explicit pipeline: `with {:ok, op} <- build_operation(...), {:ok, %{body: body}} <- Client.request(op) do ...` — no per-module dispatch or response-mapping helpers

In the error-handling section, replace the sentence describing where mapping happens with:

> `AwsSdk.Client.request/1` owns the status-code contract: 3xx → `bad_request`, HTTP 4xx → `not_found`, 5xx → `service_unavailable`, other failures → `internal_server_error`.

(Keep the `ErrorMessage`/adapter sentences as they are.)

- [ ] **Step 2: Revise the NEXT.md operations plan**

In `docs/superpowers/plans/2026-08-05-nextmd-operations.md`, rewrite every implementation tail from the old style to the new one — mechanical, same substitution as the migrations:

- JSON (SSM tasks): `perform("<Action>", data, opts) |> deserialize_response(opts, fn body -> Serializer.deserialize(body, deserialize_opts(opts)) end)` → `with {:ok, op} <- build_operation("<Action>", data, opts), {:ok, %{body: body}} <- Client.request(op) do {:ok, Serializer.deserialize(decode_body(body), deserialize_opts(opts))} end` (with each task's real action string).
- Query/XML (EC2/AutoScaling/ELBv2/IAM tasks): `"<Action>" |> perform(params, opts) |> deserialize_response(opts, fn body -> {:ok, parse_x(body)} end)` → `with {:ok, op} <- build_operation("<Action>", params, opts), {:ok, %{body: body}} <- Client.request(op) do {:ok, parse_x(body)} end`.
- S3 task 18: the `s3_request`/`deserialize_response` tail → the Task 12 shape (`build_operation(:post, bucket, nil, request_opts)` + `Client.request` + `{:ok, XMLParser.parse_delete_result(body)}`).
- Also update the two "Standard wiring recipe" sections' pipeline code to the new shape, and Task 15/16's `deserialize_response(opts, &parse_x/1)` tails per the Task 10 example.

- [ ] **Step 3: Verify** — `mix compile && mix test` (still green — docs only), and `grep -n "deserialize_response\|perform(" docs/superpowers/plans/2026-08-05-nextmd-operations.md` returns nothing.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/superpowers/plans/2026-08-05-nextmd-operations.md
git commit -m "docs: architecture and backlog plan reflect Client.request pipelines"
```
