# Sandbox Registry Abstraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four primitives every sandbox operation composes in fixed order with `AwsSdk.Sandbox.apply/5` and `register/4`, renamed to Elixir/OTP vocabulary, reducing eleven sandbox modules from 4,371 lines to roughly 2,200 with no test changes.

**Architecture:** `AwsSdk.Sandbox` is already the shared seam. It exposes `doc_examples/1`, `find!/5`, `apply_func/3` and `normalize_no_key/1`, which all 232 sandbox operations call in the same order. Task 1 adds the composed API (`apply/5`, `register/4`) alongside the old primitives and rewrites the lookup underneath both, so every commit stays green. Tasks 2–12 migrate one service sandbox module each. Task 13 deletes the old primitives.

**Tech Stack:** Elixir ~> 1.18, ExUnit, `sandbox_registry` (optional dep, `:dev`/`:test` only), `error_message`.

**Spec:** `docs/superpowers/specs/2026-08-07-sandbox-registry-abstraction-design.md`

## Global Constraints

- **No macros, no codegen.** Every sandbox operation stays a hand-written named function. Nothing may be generated.
- **`Kernel.binding/0` must never be used.** It returns variables sorted alphabetically, not in declaration order, which breaks positional application. Write the keyword list out by hand.
- **`mix compile` runs with `--warnings-as-errors` in `:test`.** Any warning fails the build.
- **Do not change any file under `test/`** except `test/test_helper.exs` (Task 1, one line) and `test/aws_sdk/sandbox_test.exs` (Task 1, new file). All 239 existing registration call sites must keep working untouched.
- **Baseline is 374 tests, 0 failures.** Every task must end at 374 or more tests, 0 failures.
- **`@type key :: String.t() | :*`.** `nil` is not a valid key.
- **Lookup order is exact → pattern → wildcard.** If several patterns match, which wins is unspecified.
- **Formatting:** run `mix format` before every commit.
- Commit messages follow the repo's convention (`refactor:`, `feat:`, `docs:`) and end with:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  ```

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/aws_sdk/sandbox.ex` | The shared registry. Gains `apply/5` + `register/4`, new three-step lookup, `:*` wildcard, `nil` guard. Old primitives become shims, then are deleted. | 1, 13 |
| `test/aws_sdk/sandbox_test.exs` | **New.** Direct tests for the three new behaviours plus lookup precedence. | 1 |
| `test/test_helper.exs` | Starts a dedicated registry for the above. | 1 |
| `lib/aws_sdk/sts/sandbox.ex` | 1 operation (A=0, E=1) | 2 |
| `lib/aws_sdk/auto_scaling/sandbox.ex` | 12 operations (A=8, B=2, E=2) | 3 |
| `lib/aws_sdk/elastic_load_balancing_v2/sandbox.ex` | 12 operations (A=6, C=4, E=2) | 4 |
| `lib/aws_sdk/logs/sandbox.ex` | 16 operations (A=13, C=2, E=1) | 5 |
| `lib/aws_sdk/ssm/sandbox.ex` | 12 operations (A=5, E=7) | 6 |
| `lib/aws_sdk/ec2/sandbox.ex` | 32 operations (A=12, C=1, E=19) | 7 |
| `lib/aws_sdk/event_bridge/sandbox.ex` | 24 operations (A=19, E=5) | 8 |
| `lib/aws_sdk/organizations/sandbox.ex` | 23 operations (A=16, E=7) | 9 |
| `lib/aws_sdk/identity_center/sandbox.ex` | 26 operations (A=25, E=1) | 10 |
| `lib/aws_sdk/s3/sandbox.ex` | 27 operations (A=26, E=1) | 11 |
| `lib/aws_sdk/iam/sandbox.ex` | 47 operations (A=37, E=10) | 12 |

Totals: A=167, B=2, C=7, E=56 — 232 operations.

## The four key shapes

Every operation falls into one of four shapes, determined by what goes in the `key` argument position.

**Shape A (167).** The key is the operation's **first parameter**, passed straight through. This was verified across all 167 — there are no exceptions.

**Shape B (2).** Two inputs joined: `"#{hook}|#{asg}"`. Both are in `auto_scaling`.

**Shape C (7).** A list input joined: `Enum.join(list, ",")`. Four in `elastic_load_balancing_v2`, two in `logs`, one in `ec2`.

**Shape E (56).** The operation takes no inputs. The key is the atom `:*`.

## The mechanical transformation

For **shape A**, an operation with parameters `p1, p2, …, opts` becomes:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Rules that apply to every shape:

1. `binding` lists **every** parameter including `opts`, in declaration order, `opts` last.
2. The key argument is written inline. Never assign it to a local variable first.
3. Parameter names are copied verbatim from the existing function head — do not rename them.
4. `set_*_responses` takes `entries` and passes it straight through. The `normalize_no_key` call is deleted; `register/4` does that work.
5. Blank line between the `binding` assignment and the `Sandbox.apply` call.

Shapes B, C and E differ only in the key argument, and every one of those nine operations is written out in full in its task.

---

### Task 1: Add the composed API to `AwsSdk.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/sandbox.ex` (whole file)
- Create: `test/aws_sdk/sandbox_test.exs`
- Modify: `test/test_helper.exs:11` (add one line before `ExUnit.start()`)

**Interfaces:**
- Produces:
  - `AwsSdk.Sandbox.apply(registry :: atom, module :: module, function :: atom, key :: String.t() | :*, binding :: keyword) :: term` — raises on miss
  - `AwsSdk.Sandbox.register(registry :: atom, module :: module, function :: atom, entries :: [{String.t() | Regex.t() | :*, function} | function]) :: :ok`
  - Unchanged: `start_link/1`, `disable/2`, `disabled?/2`
  - Temporarily retained shims, deleted in Task 13: `find!/5`, `apply_func/3`, `doc_examples/1`, `normalize_no_key/1`
- Consumes: `SandboxRegistry.register/4`, `SandboxRegistry.lookup/2`

This task introduces genuinely new behaviour, so it is written test-first.

- [ ] **Step 1: Add a registry for the core tests**

In `test/test_helper.exs`, add this line immediately after the `AwsSdk.SSM.Sandbox.start_link()` line and before `ExUnit.start()`:

```elixir
AwsSdk.Sandbox.start_link(:aws_sandbox_core_test)
```

- [ ] **Step 2: Write the failing tests**

Create `test/aws_sdk/sandbox_test.exs`:

```elixir
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
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `mix test test/aws_sdk/sandbox_test.exs`

Expected: FAIL — `AwsSdk.Sandbox.register/4` and `AwsSdk.Sandbox.apply/5` are undefined.

- [ ] **Step 4: Rewrite `lib/aws_sdk/sandbox.ex`**

Replace the entire file with:

```elixir
if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.Sandbox do
    @moduledoc """
    Process-scoped registry of stub functions, shared by every
    `AwsSdk.<Service>.Sandbox` module.

    A test registers functions against its own PID; the service's sandbox
    module looks one up and applies it in place of an HTTP call. Nothing here
    is specific to AWS — it stores funs keyed by the function they stand in
    for and a lookup key.

    Each service's sandbox module holds its registry name in `@registry` and
    writes one pair of functions per operation:

        def create_user_response(name, opts) do
          binding = [name: name, opts: opts]

          Sandbox.apply(@registry, __MODULE__, :create_user, name, binding)
        end

        def set_create_user_responses(entries) do
          Sandbox.register(@registry, __MODULE__, :create_user, entries)
        end

    ## Convention

    Sandbox modules name their registration function
    `set_<function>_responses/1`. This module relies on that when building the
    setup example shown in error messages. A module that names its setter
    otherwise still works, but its errors will point at a function that does
    not exist.
    """

    @state "state"
    @disabled "disabled"
    @sleep 10
    @keys :unique

    @typedoc """
    Selects which registered stub a call resolves to.

    A binary names one call. `:*` applies to every call of that function.
    """
    @type key :: String.t() | :*

    @doc false
    def start_link(registry), do: Registry.start_link(keys: @keys, name: registry)

    @doc false
    def disable(registry, module) do
      with {:error, :registry_not_started} <-
             SandboxRegistry.register(registry, @disabled, %{}, @keys) do
        raise_not_started!(module)
      end
    end

    @doc false
    def disabled?(registry, module) do
      case SandboxRegistry.lookup(registry, @disabled) do
        {:ok, _} -> true
        {:error, :registry_not_started} -> raise_not_started!(module)
        {:error, :pid_not_registered} -> false
      end
    end

    @doc """
    Looks up the stub registered for `function` and applies it.

    This is the entire body of a sandbox operation: resolve the function the
    calling process registered, then call it with the operation's inputs.

    ## Arguments

      * `registry` — the service's registry name, held as `@registry` in each
        `AwsSdk.<Service>.Sandbox` (e.g. `:aws_iam_sandbox`).
      * `module` — the calling sandbox module. Diagnostic only: each service
        owns its own registry, so the registry key is `{function, key}` and
        `module` never participates in lookup. It exists to build the error
        message.
      * `function` — the operation as an atom (`:create_log_stream`). Half of
        the registry key; a stub registered under another function never
        matches.
      * `key` — the other half. A binary names one call, letting a test
        register a different result per resource; `:*` applies to every call
        of `function`. `nil` is not valid and fails the guard.
      * `binding` — the operation's parameters as a keyword list in
        declaration order, `opts` last. The names build the `fn` shapes shown
        in error messages; the values are what the stub is applied to. Write
        this list out by hand — `Kernel.binding/0` sorts alphabetically rather
        than by declaration order and would apply the wrong values.

    ## Lookup

    By `{function, key}`, in three ordered steps:

      1. **exact** — a binary key equal to `key`
      2. **pattern** — a `Regex` key registered for the same `function` whose
         pattern matches `key`. Skipped unless `key` is a binary, so
         `Regex.match?/2` is never handed an atom.
      3. **wildcard** — a stub registered under `:*`

    If several patterns match, which one wins is unspecified — register
    non-overlapping patterns. Stubs are held in a map, and map iteration is
    neither insertion nor sorted order.

    ## Return value

    Whatever the stub returns, unaltered — this module never inspects or wraps
    it. Tests register the service's own shapes:

        {:ok, %{log_streams: [], next_token: nil}}
        {:error, ErrorMessage.not_found("resource not found.", %{status: 404})}

    The stub is applied at its own arity, so a test writes only the parameters
    it cares about. Arity `0` is called with no arguments; any arity up to
    `length(binding)` receives that many leading values.

    ## Raises

      * the registry was never started for `module` — the message points at
        `test_helper.exs`
      * the calling process registered no stubs at all
      * stubs exist for this process but none match `{function, key}` — the
        message lists what was registered
      * a registered value is not a function
      * a registered function's arity exceeds `length(binding)`

    ## Examples

        # In AwsSdk.Logs.Sandbox.
        def create_log_stream_response(group, stream, opts) do
          binding = [group: group, stream: stream, opts: opts]

          Sandbox.apply(@registry, __MODULE__, :create_log_stream, group, binding)
        end

        # A test registers against that key:
        AwsSdk.Logs.Sandbox.set_create_log_stream_responses([
          {"my-group", fn -> {:ok, %{}} end}
        ])

        AwsSdk.Logs.create_log_stream("my-group", "stream-a", sandbox: [enabled: true])
        #=> {:ok, %{}}

        # A different group does not match, so the call raises rather than
        # returning a response meant for another test.
        AwsSdk.Logs.create_log_stream("other", "stream-a", sandbox: [enabled: true])
        #=> ** (RuntimeError) Function not found.

        # A higher-arity stub receives the values in declaration order.
        AwsSdk.Logs.Sandbox.set_create_log_stream_responses([
          {~r/^prod-/, fn group, stream, opts -> {:ok, %{group: group, stream: stream}} end}
        ])

        AwsSdk.Logs.create_log_stream("prod-api", "stream-a", sandbox: [enabled: true])
        #=> {:ok, %{group: "prod-api", stream: "stream-a"}}

    An operation with no inputs passes `:*`:

        def list_users_response(opts) do
          binding = [opts: opts]

          Sandbox.apply(@registry, __MODULE__, :list_users, :*, binding)
        end
    """
    @spec apply(atom, module, atom, key, keyword) :: term
    def apply(registry, module, function, key, binding)
        when is_binary(key) or key === :* do
      names = Keyword.keys(binding)
      args = Keyword.values(binding)
      examples = examples(names)
      fun = fetch!(registry, module, function, key, examples)
      arity = :erlang.fun_info(fun)[:arity]

      case arity do
        0 -> fun.()
        n when n <= length(args) -> Kernel.apply(fun, Enum.take(args, n))
        _ -> raise_unsupported_arity(fun, examples)
      end
    end

    @doc """
    Registers stub functions for `function` against the calling process.

    Each entry is a `{key, fun}` tuple, or a bare `fun` — shorthand for
    `{:*, fun}`, used by operations that take no inputs.

    `key` is an exact binary compared for equality, a `Regex` matched against
    the key the operation passes to `apply/5`, or `:*`.

    Registration is per-process and additive: registering a second function
    leaves the first in place; registering the same `{function, key}` twice
    replaces the earlier stub. Returns `:ok`, sleeping briefly so the
    registration is visible before the test proceeds. Raises if the registry
    was never started for `module`.

    ## Examples

        AwsSdk.IAM.Sandbox.set_get_user_responses([
          {"alice", fn -> {:ok, %{user: %{user_name: "alice"}}} end},
          {"bob", fn -> {:error, ErrorMessage.not_found("resource not found.")} end}
        ])

        AwsSdk.IAM.Sandbox.set_get_user_responses([
          {~r/^svc-/, fn name -> {:ok, %{user: %{user_name: name}}} end}
        ])

        # Applies to every call, whatever the key.
        AwsSdk.IAM.Sandbox.set_get_user_responses([
          {:*, fn name -> {:error, ErrorMessage.not_found("no such user", %{name: name})} end}
        ])

        # No inputs — the bare form.
        AwsSdk.IAM.Sandbox.set_list_users_responses([fn -> {:ok, %{users: []}} end])
    """
    @spec register(atom, module, atom, [{key | Regex.t(), function} | function]) :: :ok
    def register(registry, module, function, entries) do
      :ok =
        entries
        |> Enum.map(fn
          {_key, _fun} = entry -> entry
          fun when is_function(fun) -> {:*, fun}
        end)
        |> Map.new(fn {key, fun} -> {{function, key}, fun} end)
        |> then(&SandboxRegistry.register(registry, @state, &1, @keys))
        |> then(fn
          :ok -> :ok
          {:error, :registry_not_started} -> raise_not_started!(module)
        end)

      :ok = Process.sleep(@sleep)
    end

    # -------------------------------------------------------------------------
    # Deprecated primitives — retained until every sandbox module is migrated
    # to apply/5 and register/4, then deleted.
    # -------------------------------------------------------------------------

    @doc false
    def set_responses(registry, module, action, tuples) do
      register(registry, module, action, tuples)
    end

    @doc false
    def normalize_no_key(items) do
      Enum.map(items, fn
        {_key, _func} = tuple -> tuple
        func when is_function(func) -> {"*", func}
      end)
    end

    @doc false
    def find!(registry, module, action, name, doc_examples) do
      fetch!(registry, module, action, name, doc_examples)
    end

    @doc false
    def apply_func(func, args, doc_examples) do
      arity = :erlang.fun_info(func)[:arity]

      case arity do
        0 -> func.()
        n when n <= length(args) -> Kernel.apply(func, Enum.take(args, n))
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc false
    def doc_examples(arg_names) do
      full = Enum.map_join(arg_names ++ [:opts], ", ", &to_string/1)

      case arg_names do
        [] -> ["fn -> ... end", "fn opts -> ... end"]
        [first | _] -> ["fn -> ... end", "fn #{first} -> ... end", "fn #{full} -> ... end"]
      end
    end

    # -------------------------------------------------------------------------
    # Lookup
    # -------------------------------------------------------------------------

    defp fetch!(registry, module, function, key, examples) do
      case SandboxRegistry.lookup(registry, @state) do
        {:ok, state} ->
          fetch_stub!(state, module, function, key, examples)

        {:error, :pid_not_registered} ->
          raise """
          No functions have been registered for #{inspect(self())}.

          Function: #{inspect(function)}
          Key: #{inspect(key)}

          Add one of the following patterns to your test setup:

          #{format_example(module, function, examples)}

          Replace `_response` with the value you want the sandbox to return.
          """

        {:error, :registry_not_started} ->
          raise_not_started!(module)
      end
    end

    defp fetch_stub!(state, module, function, key, examples) do
      exact = Map.get(state, {function, key})
      pattern = if is_binary(key), do: match_pattern(state, function, key)
      wildcard = Map.get(state, {function, :*})

      case exact || pattern || wildcard do
        fun when is_function(fun) ->
          fun

        nil ->
          registered =
            Enum.map_join(state, "\n", fn {registered_key, value} ->
              " #{inspect(registered_key)} => #{inspect(value)}"
            end)

          example = indent(format_example(module, function, examples), "  ")

          raise """
          Function not found.

            function: #{inspect(function)}
            key: #{inspect(key)}
            pid: #{inspect(self())}

          Found:

          #{registered}

          ---

          You need to register stubs for `#{inspect(function)}` calls.

          #{example}
          """

        other ->
          raise """
          Unrecognized input for #{inspect({function, key})} in #{inspect(self())}.

          Found value:

          #{inspect(other)}

          To fix this, update your test setup:

          #{format_example(module, function, examples)}
          """
      end
    end

    defp match_pattern(state, function, key) do
      Enum.find_value(state, fn
        {{^function, %Regex{} = regex}, fun} -> if Regex.match?(regex, key), do: fun
        _entry -> nil
      end)
    end

    # -------------------------------------------------------------------------
    # Error message construction
    # -------------------------------------------------------------------------

    defp examples(names) do
      first = List.first(names)
      full = Enum.map_join(names, ", ", &to_string/1)

      Enum.uniq(["fn -> ... end", "fn #{first} -> ... end", "fn #{full} -> ... end"])
    end

    defp indent(text, prefix) do
      text
      |> String.split("\n", trim: false)
      |> Enum.map_join("\n", &"#{prefix}#{&1}")
    end

    defp format_example(module, function, examples) do
      """
      alias #{inspect(module)}

      setup do
        #{inspect(module)}.set_#{function}_responses([
          #{Enum.map_join(examples, "\n    # or\n", &("    " <> &1))}
          # or
          {~r|pattern|, fn -> _response end}
        ])
      end
      """
    end

    defp raise_unsupported_arity(fun, examples) do
      raise """
      This function's signature is not supported: #{inspect(fun)}

      Please provide a function with one of the following arities (0-#{length(examples) - 1}):

      #{Enum.map_join(examples, "\n", &("    " <> &1))}
      """
    end

    defp raise_not_started!(module) do
      raise """
      Registry not started for #{inspect(module)}.

      To fix this, add the following line to your `test_helper.exs`:

          #{inspect(module)}.start_link()
      """
    end
  end
end
```

Two things to note about this file:

- Defining `apply/5` does not conflict with `Kernel.apply/2,3` — import conflicts are per name **and** arity. The single internal use is written `Kernel.apply/2` for clarity.
- The old `find!/5` and `set_responses/4` now delegate to the new lookup and `register/4`. Unmigrated modules pass the string `"*"`, which resolves at lookup step 1 exactly as before, so their behaviour is unchanged.

- [ ] **Step 5: Run the new tests to verify they pass**

Run: `mix test test/aws_sdk/sandbox_test.exs`

Expected: PASS, 13 tests.

- [ ] **Step 6: Run the full suite to verify nothing regressed**

Run: `mix test`

Expected: PASS, 387 tests (374 baseline + 13 new), 0 failures.

- [ ] **Step 7: Format and commit**

```bash
mix format
git add lib/aws_sdk/sandbox.ex test/aws_sdk/sandbox_test.exs test/test_helper.exs
git commit -m "feat: add AwsSdk.Sandbox.apply/5 and register/4

Composes doc_examples/find!/apply_func into one call and replaces the
\"*\" sentinel with :*, a real wildcard matched as lookup step 3. nil is
no longer a valid key.

The old primitives remain as shims over the new lookup so the eleven
service sandbox modules can migrate one at a time.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Migrate `AwsSdk.STS.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/sts/sandbox.ex` (1 operation, shape E)
- Test: `test/aws_sdk/sts/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

This is the smallest module — one operation — and validates the pattern end to end before the larger migrations.

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/sts/sandbox_test.exs`

Expected: PASS. This is a refactor, so the existing tests are the specification. Note the test count.

- [ ] **Step 2: Add the alias**

In `lib/aws_sdk/sts/sandbox.ex`, immediately after the `@registry` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the one operation**

`get_caller_identity` takes no inputs, so its key is `:*`:

```elixir
    def get_caller_identity_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :get_caller_identity, :*, binding)
    end

    def set_get_caller_identity_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :get_caller_identity, entries)
    end
```

- [ ] **Step 4: Verify no old-API calls remain in this file**

Run: `grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/sts/sandbox.ex`

Expected: no output.

- [ ] **Step 5: Run the tests**

Run: `mix test test/aws_sdk/sts/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 6: Format and commit**

```bash
mix format
git add lib/aws_sdk/sts/sandbox.ex
git commit -m "refactor: migrate STS sandbox to Sandbox.apply/5

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Migrate `AwsSdk.AutoScaling.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/auto_scaling/sandbox.ex` (12 operations: A=8, B=2, E=2)
- Test: `test/aws_sdk/auto_scaling/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

This module holds both shape-B operations, so it proves the derived-key path.

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/auto_scaling/sandbox_test.exs`

Expected: PASS. Note the test count.

- [ ] **Step 2: Add the alias**

After the `@registry :aws_auto_scaling_sandbox` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the 8 shape-A operations**

For each of `describe_instance_refreshes`, `describe_scaling_activities`, `start_instance_refresh`, `cancel_instance_refresh`, `rollback_instance_refresh`, `set_instance_health`, `terminate_instance_in_auto_scaling_group`, `set_desired_capacity`, apply this transformation. The key is the **first parameter**, `binding` lists every parameter including `opts` in declaration order, and the key is written inline:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked examples from this file:

```elixir
    def describe_instance_refreshes_response(asg, opts) do
      binding = [asg: asg, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_instance_refreshes, asg, binding)
    end

    def set_describe_instance_refreshes_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_instance_refreshes, entries)
    end

    def set_instance_health_response(instance_id, health_status, opts) do
      binding = [instance_id: instance_id, health_status: health_status, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :set_instance_health, instance_id, binding)
    end

    def set_set_instance_health_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :set_instance_health, entries)
    end

    def terminate_instance_in_auto_scaling_group_response(instance_id, should_decrement, opts) do
      binding = [instance_id: instance_id, should_decrement: should_decrement, opts: opts]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :terminate_instance_in_auto_scaling_group,
        instance_id,
        binding
      )
    end

    def set_terminate_instance_in_auto_scaling_group_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :terminate_instance_in_auto_scaling_group, entries)
    end
```

Note that `set_set_instance_health_responses` keeps its doubled `set_` prefix — the operation is named `set_instance_health`, and renaming it would break `test/aws_sdk/auto_scaling/sandbox_test.exs`.

- [ ] **Step 4: Rewrite the 2 shape-B operations**

Neither input alone identifies these calls, so the key joins two of them:

```elixir
    def complete_lifecycle_action_response(hook, asg, result, opts) do
      binding = [hook: hook, asg: asg, result: result, opts: opts]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :complete_lifecycle_action,
        "#{hook}|#{asg}",
        binding
      )
    end

    def set_complete_lifecycle_action_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :complete_lifecycle_action, entries)
    end

    def record_lifecycle_action_heartbeat_response(hook, asg, opts) do
      binding = [hook: hook, asg: asg, opts: opts]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :record_lifecycle_action_heartbeat,
        "#{hook}|#{asg}",
        binding
      )
    end

    def set_record_lifecycle_action_heartbeat_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :record_lifecycle_action_heartbeat, entries)
    end
```

- [ ] **Step 5: Rewrite the 2 shape-E operations**

`describe_auto_scaling_groups` and `describe_auto_scaling_instances` take no inputs, so the key is `:*`:

```elixir
    def describe_auto_scaling_groups_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_auto_scaling_groups, :*, binding)
    end

    def set_describe_auto_scaling_groups_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_auto_scaling_groups, entries)
    end

    def describe_auto_scaling_instances_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_auto_scaling_instances, :*, binding)
    end

    def set_describe_auto_scaling_instances_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_auto_scaling_instances, entries)
    end
```

- [ ] **Step 6: Verify the counts and that no old-API calls remain**

```bash
grep -c 'Sandbox.apply(' lib/aws_sdk/auto_scaling/sandbox.ex      # expect 12
grep -c 'Sandbox.register(' lib/aws_sdk/auto_scaling/sandbox.ex   # expect 12
grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/auto_scaling/sandbox.ex
```

Expected: 12, 12, and no output from the last command.

- [ ] **Step 7: Run the tests**

Run: `mix test test/aws_sdk/auto_scaling/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 8: Format and commit**

```bash
mix format
git add lib/aws_sdk/auto_scaling/sandbox.ex
git commit -m "refactor: migrate AutoScaling sandbox to Sandbox.apply/5

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Migrate `AwsSdk.ElasticLoadBalancingV2.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/elastic_load_balancing_v2/sandbox.ex` (12 operations: A=6, C=4, E=2)
- Test: `test/aws_sdk/elastic_load_balancing_v2/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

This module holds four of the seven shape-C operations, so it proves the list-key path.

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/elastic_load_balancing_v2/sandbox_test.exs`

Expected: PASS. Note the test count.

- [ ] **Step 2: Add the alias**

After the `@registry :aws_elastic_load_balancing_v2_sandbox` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the 6 shape-A operations**

The key is the **first parameter**, `binding` lists every parameter including `opts` in declaration order, and the key is written inline:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked example from this file:

```elixir
    def describe_target_health_response(target_group_arn, opts) do
      binding = [target_group_arn: target_group_arn, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_target_health, target_group_arn, binding)
    end

    def set_describe_target_health_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_target_health, entries)
    end
```

- [ ] **Step 4: Rewrite the 4 shape-C operations**

The identifying input is a list, which is neither an exact string key nor a `Regex.match?/2` subject, so it is joined:

```elixir
    def describe_target_groups_by_names_response(names, opts) do
      binding = [names: names, opts: opts]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :describe_target_groups_by_names,
        Enum.join(names, ","),
        binding
      )
    end

    def set_describe_target_groups_by_names_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_target_groups_by_names, entries)
    end

    def describe_target_groups_by_arns_response(arns, opts) do
      binding = [arns: arns, opts: opts]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :describe_target_groups_by_arns,
        Enum.join(arns, ","),
        binding
      )
    end

    def set_describe_target_groups_by_arns_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_target_groups_by_arns, entries)
    end

    def describe_listeners_by_arns_response(listener_arns, opts) do
      binding = [listener_arns: listener_arns, opts: opts]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :describe_listeners_by_arns,
        Enum.join(listener_arns, ","),
        binding
      )
    end

    def set_describe_listeners_by_arns_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_listeners_by_arns, entries)
    end

    def describe_rules_by_arns_response(rule_arns, opts) do
      binding = [rule_arns: rule_arns, opts: opts]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :describe_rules_by_arns,
        Enum.join(rule_arns, ","),
        binding
      )
    end

    def set_describe_rules_by_arns_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_rules_by_arns, entries)
    end
```

- [ ] **Step 5: Rewrite the 2 shape-E operations**

`describe_target_groups` and `describe_load_balancers` take no inputs:

```elixir
    def describe_target_groups_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_target_groups, :*, binding)
    end

    def set_describe_target_groups_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_target_groups, entries)
    end

    def describe_load_balancers_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_load_balancers, :*, binding)
    end

    def set_describe_load_balancers_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_load_balancers, entries)
    end
```

- [ ] **Step 6: Verify the counts and that no old-API calls remain**

```bash
grep -c 'Sandbox.apply(' lib/aws_sdk/elastic_load_balancing_v2/sandbox.ex      # expect 12
grep -c 'Sandbox.register(' lib/aws_sdk/elastic_load_balancing_v2/sandbox.ex   # expect 12
grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/elastic_load_balancing_v2/sandbox.ex
```

Expected: 12, 12, and no output from the last command.

- [ ] **Step 7: Run the tests**

Run: `mix test test/aws_sdk/elastic_load_balancing_v2/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 8: Format and commit**

```bash
mix format
git add lib/aws_sdk/elastic_load_balancing_v2/sandbox.ex
git commit -m "refactor: migrate ELBv2 sandbox to Sandbox.apply/5

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Migrate `AwsSdk.Logs.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/logs/sandbox.ex` (16 operations: A=13, C=2, E=1)
- Test: `test/aws_sdk/logs/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/logs/sandbox_test.exs`

Expected: PASS. Note the test count.

- [ ] **Step 2: Add the alias**

After the `@registry :aws_logs_sandbox` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the 13 shape-A operations**

The key is the **first parameter**, `binding` lists every parameter including `opts` in declaration order, and the key is written inline:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked examples from this file, including a five-parameter operation:

```elixir
    def create_log_stream_response(group, stream, opts) do
      binding = [group: group, stream: stream, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :create_log_stream, group, binding)
    end

    def set_create_log_stream_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :create_log_stream, entries)
    end

    def start_query_response(group, start_time, end_time, query, opts) do
      binding = [
        group: group,
        start_time: start_time,
        end_time: end_time,
        query: query,
        opts: opts
      ]

      Sandbox.apply(@registry, __MODULE__, :start_query, group, binding)
    end

    def set_start_query_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :start_query, entries)
    end
```

- [ ] **Step 4: Rewrite the 2 shape-C operations**

The identifying input is a list, so it is joined. Note that `binding` still carries the real list — only the key is joined:

```elixir
    def start_query_for_log_groups_response(groups, start_time, end_time, query, opts) do
      binding = [
        groups: groups,
        start_time: start_time,
        end_time: end_time,
        query: query,
        opts: opts
      ]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :start_query_for_log_groups,
        Enum.join(groups, ","),
        binding
      )
    end

    def set_start_query_for_log_groups_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :start_query_for_log_groups, entries)
    end

    def start_query_by_identifiers_response(identifiers, start_time, end_time, query, opts) do
      binding = [
        identifiers: identifiers,
        start_time: start_time,
        end_time: end_time,
        query: query,
        opts: opts
      ]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :start_query_by_identifiers,
        Enum.join(identifiers, ","),
        binding
      )
    end

    def set_start_query_by_identifiers_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :start_query_by_identifiers, entries)
    end
```

- [ ] **Step 5: Rewrite the 1 shape-E operation**

```elixir
    def describe_log_groups_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_log_groups, :*, binding)
    end

    def set_describe_log_groups_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_log_groups, entries)
    end
```

- [ ] **Step 6: Verify the counts and that no old-API calls remain**

```bash
grep -c 'Sandbox.apply(' lib/aws_sdk/logs/sandbox.ex      # expect 16
grep -c 'Sandbox.register(' lib/aws_sdk/logs/sandbox.ex   # expect 16
grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/logs/sandbox.ex
```

Expected: 16, 16, and no output from the last command.

- [ ] **Step 7: Run the tests**

Run: `mix test test/aws_sdk/logs/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 8: Format and commit**

```bash
mix format
git add lib/aws_sdk/logs/sandbox.ex
git commit -m "refactor: migrate Logs sandbox to Sandbox.apply/5

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Migrate `AwsSdk.SSM.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/ssm/sandbox.ex` (12 operations: A=5, E=7)
- Test: `test/aws_sdk/ssm/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/ssm/sandbox_test.exs`

Expected: PASS. Note the test count.

- [ ] **Step 2: Add the alias**

After the `@registry :aws_ssm_sandbox` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the 5 shape-A operations**

The key is the **first parameter**, `binding` lists every parameter including `opts` in declaration order, and the key is written inline:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked example from this file:

```elixir
    def get_parameter_response(name, opts) do
      binding = [name: name, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :get_parameter, name, binding)
    end

    def set_get_parameter_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :get_parameter, entries)
    end
```

- [ ] **Step 4: Rewrite the 7 shape-E operations**

These take no inputs: `get_parameters`, `delete_parameters`, `describe_parameters`, `describe_instance_information`, `send_command`, `send_command_by_targets`, `list_command_invocations`.

```elixir
def <op>_response(opts) do
  binding = [opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, :*, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked example:

```elixir
    def describe_parameters_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_parameters, :*, binding)
    end

    def set_describe_parameters_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_parameters, entries)
    end
```

- [ ] **Step 5: Verify the counts and that no old-API calls remain**

```bash
grep -c 'Sandbox.apply(' lib/aws_sdk/ssm/sandbox.ex      # expect 12
grep -c 'Sandbox.register(' lib/aws_sdk/ssm/sandbox.ex   # expect 12
grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/ssm/sandbox.ex
```

Expected: 12, 12, and no output from the last command.

- [ ] **Step 6: Run the tests**

Run: `mix test test/aws_sdk/ssm/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 7: Format and commit**

```bash
mix format
git add lib/aws_sdk/ssm/sandbox.ex
git commit -m "refactor: migrate SSM sandbox to Sandbox.apply/5

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Migrate `AwsSdk.EC2.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/ec2/sandbox.ex` (32 operations: A=12, C=1, E=19)
- Test: `test/aws_sdk/ec2/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

This task contains the one operation whose key semantics change: `create_tags`.

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/ec2/sandbox_test.exs`

Expected: PASS. Note the test count.

- [ ] **Step 2: Add the alias**

After the `@registry :aws_ec2_sandbox` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the 12 shape-A operations**

The key is the **first parameter**, `binding` lists every parameter including `opts` in declaration order, and the key is written inline:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked example from this file:

```elixir
    def create_security_group_response(name, opts) do
      binding = [name: name, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :create_security_group, name, binding)
    end

    def set_create_security_group_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :create_security_group, entries)
    end
```

- [ ] **Step 4: Rewrite `create_tags` — the one semantic change**

It currently keys off `List.first(resource_ids) || "*"`. That shape existed only because `List.first/1` returns `nil` on an empty list and `nil` had to become something. With `nil` now invalid, it keys off its list the way the other six shape-C operations do. `Enum.join([], ",")` is `""` — a binary — so there is no fallback and no special case:

```elixir
    def create_tags_response(resource_ids, opts) do
      binding = [resource_ids: resource_ids, opts: opts]

      Sandbox.apply(
        @registry,
        __MODULE__,
        :create_tags,
        Enum.join(resource_ids, ","),
        binding
      )
    end

    def set_create_tags_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :create_tags, entries)
    end
```

The existing test at `test/aws_sdk/ec2/sandbox_test.exs:133` registers `{"i-1", ...}` and calls `create_tags(["i-1"], ...)`. `Enum.join(["i-1"], ",")` is `"i-1"`, so it still matches and the test needs no change.

- [ ] **Step 5: Rewrite the 19 shape-E operations**

These take no inputs: `describe_security_groups`, `delete_security_group`, `describe_vpcs`, `describe_subnets`, `describe_instances`, `describe_images`, `describe_tags`, `describe_launch_templates`, `describe_launch_template_versions`, `terminate_instances`, `describe_network_acls`, `describe_route_tables`, `describe_key_pairs`, `describe_security_group_rules`, `describe_snapshots`, `describe_network_interfaces`, `describe_instance_status`, `describe_iam_instance_profile_associations`, `describe_network_insights_analyses`.

```elixir
def <op>_response(opts) do
  binding = [opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, :*, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked example:

```elixir
    def describe_instances_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_instances, :*, binding)
    end

    def set_describe_instances_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_instances, entries)
    end
```

- [ ] **Step 6: Verify the counts and that no old-API calls remain**

```bash
grep -c 'Sandbox.apply(' lib/aws_sdk/ec2/sandbox.ex      # expect 32
grep -c 'Sandbox.register(' lib/aws_sdk/ec2/sandbox.ex   # expect 32
grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/ec2/sandbox.ex
```

Expected: 32, 32, and no output from the last command.

- [ ] **Step 7: Run the tests**

Run: `mix test test/aws_sdk/ec2/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 8: Format and commit**

```bash
mix format
git add lib/aws_sdk/ec2/sandbox.ex
git commit -m "refactor: migrate EC2 sandbox to Sandbox.apply/5

create_tags now keys off its joined resource_ids list like the other
list-keyed operations, dropping the List.first/1 fallback that only
existed to avoid a nil key.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Migrate `AwsSdk.EventBridge.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/event_bridge/sandbox.ex` (24 operations: A=19, E=5)
- Test: `test/aws_sdk/event_bridge/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/event_bridge/sandbox_test.exs`

Expected: PASS. Note the test count.

- [ ] **Step 2: Add the alias**

After the `@registry :aws_event_bridge_sandbox` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the 19 shape-A operations**

The key is the **first parameter**, `binding` lists every parameter including `opts` in declaration order, and the key is written inline:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked examples from this file, including a five-parameter operation:

```elixir
    def describe_rule_response(name, opts) do
      binding = [name: name, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_rule, name, binding)
    end

    def set_describe_rule_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_rule, entries)
    end

    def create_api_destination_response(name, connection_arn, invocation_endpoint, http_method, opts) do
      binding = [
        name: name,
        connection_arn: connection_arn,
        invocation_endpoint: invocation_endpoint,
        http_method: http_method,
        opts: opts
      ]

      Sandbox.apply(@registry, __MODULE__, :create_api_destination, name, binding)
    end

    def set_create_api_destination_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :create_api_destination, entries)
    end
```

- [ ] **Step 4: Rewrite the 5 shape-E operations**

These take no inputs: `list_rules`, `list_connections`, `list_api_destinations`, `list_event_buses`, `put_events`.

```elixir
def <op>_response(opts) do
  binding = [opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, :*, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked example:

```elixir
    def list_rules_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :list_rules, :*, binding)
    end

    def set_list_rules_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :list_rules, entries)
    end
```

- [ ] **Step 5: Verify the counts and that no old-API calls remain**

```bash
grep -c 'Sandbox.apply(' lib/aws_sdk/event_bridge/sandbox.ex      # expect 24
grep -c 'Sandbox.register(' lib/aws_sdk/event_bridge/sandbox.ex   # expect 24
grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/event_bridge/sandbox.ex
```

Expected: 24, 24, and no output from the last command.

- [ ] **Step 6: Run the tests**

Run: `mix test test/aws_sdk/event_bridge/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 7: Format and commit**

```bash
mix format
git add lib/aws_sdk/event_bridge/sandbox.ex
git commit -m "refactor: migrate EventBridge sandbox to Sandbox.apply/5

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Migrate `AwsSdk.Organizations.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/organizations/sandbox.ex` (23 operations: A=16, E=7)
- Test: `test/aws_sdk/organizations/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/organizations/sandbox_test.exs`

Expected: PASS. Note the test count.

- [ ] **Step 2: Add the alias**

After the `@registry :aws_organizations_sandbox` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the 16 shape-A operations**

The key is the **first parameter**, `binding` lists every parameter including `opts` in declaration order, and the key is written inline:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked example from this file:

```elixir
    def describe_account_response(account_id, opts) do
      binding = [account_id: account_id, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :describe_account, account_id, binding)
    end

    def set_describe_account_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :describe_account, entries)
    end
```

- [ ] **Step 4: Rewrite the 7 shape-E operations**

These take no inputs: `create_organization`, `delete_organization`, `describe_organization`, `list_accounts`, `list_roots`, `list_delegated_administrators`, `list_aws_service_access_for_organization`.

```elixir
def <op>_response(opts) do
  binding = [opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, :*, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked example:

```elixir
    def list_accounts_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :list_accounts, :*, binding)
    end

    def set_list_accounts_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :list_accounts, entries)
    end
```

- [ ] **Step 5: Verify the counts and that no old-API calls remain**

```bash
grep -c 'Sandbox.apply(' lib/aws_sdk/organizations/sandbox.ex      # expect 23
grep -c 'Sandbox.register(' lib/aws_sdk/organizations/sandbox.ex   # expect 23
grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/organizations/sandbox.ex
```

Expected: 23, 23, and no output from the last command.

- [ ] **Step 6: Run the tests**

Run: `mix test test/aws_sdk/organizations/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 7: Format and commit**

```bash
mix format
git add lib/aws_sdk/organizations/sandbox.ex
git commit -m "refactor: migrate Organizations sandbox to Sandbox.apply/5

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Migrate `AwsSdk.IdentityCenter.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/identity_center/sandbox.ex` (26 operations: A=25, E=1)
- Test: `test/aws_sdk/identity_center/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/identity_center/sandbox_test.exs`

Expected: PASS. Note the test count.

- [ ] **Step 2: Add the alias**

After the `@registry :aws_identity_center_sandbox` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the 25 shape-A operations**

The key is the **first parameter**, `binding` lists every parameter including `opts` in declaration order, and the key is written inline:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked example from this file — most operations here key off `instance_arn`:

```elixir
    def list_account_assignments_response(instance_arn, account_id, permission_set_arn, opts) do
      binding = [
        instance_arn: instance_arn,
        account_id: account_id,
        permission_set_arn: permission_set_arn,
        opts: opts
      ]

      Sandbox.apply(@registry, __MODULE__, :list_account_assignments, instance_arn, binding)
    end

    def set_list_account_assignments_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :list_account_assignments, entries)
    end
```

- [ ] **Step 4: Rewrite the 1 shape-E operation**

```elixir
    def list_instances_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :list_instances, :*, binding)
    end

    def set_list_instances_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :list_instances, entries)
    end
```

- [ ] **Step 5: Verify the counts and that no old-API calls remain**

```bash
grep -c 'Sandbox.apply(' lib/aws_sdk/identity_center/sandbox.ex      # expect 26
grep -c 'Sandbox.register(' lib/aws_sdk/identity_center/sandbox.ex   # expect 26
grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/identity_center/sandbox.ex
```

Expected: 26, 26, and no output from the last command.

- [ ] **Step 6: Run the tests**

Run: `mix test test/aws_sdk/identity_center/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 7: Format and commit**

```bash
mix format
git add lib/aws_sdk/identity_center/sandbox.ex
git commit -m "refactor: migrate IdentityCenter sandbox to Sandbox.apply/5

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Migrate `AwsSdk.S3.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/s3/sandbox.ex` (27 operations: A=26, E=1)
- Test: `test/aws_sdk/s3/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

S3 has the widest function heads — `copy_parts/7` takes six inputs plus `opts`.

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/s3/sandbox_test.exs`

Expected: PASS. Note the test count.

- [ ] **Step 2: Add the alias**

After the `@registry :aws_s3_sandbox` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the 26 shape-A operations**

The key is the **first parameter**, `binding` lists every parameter including `opts` in declaration order, and the key is written inline. Take particular care with the wide heads — the values must stay in declaration order or a stub written as `fn bucket, key -> end` receives the wrong arguments:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked examples from this file, including the widest heads:

```elixir
    def list_parts_response(bucket, key, upload_id, part_number_marker, opts) do
      binding = [
        bucket: bucket,
        key: key,
        upload_id: upload_id,
        part_number_marker: part_number_marker,
        opts: opts
      ]

      Sandbox.apply(@registry, __MODULE__, :list_parts, bucket, binding)
    end

    def set_list_parts_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :list_parts, entries)
    end

    def copy_object_response(dest_bucket, dest_key, src_bucket, src_key, opts) do
      binding = [
        dest_bucket: dest_bucket,
        dest_key: dest_key,
        src_bucket: src_bucket,
        src_key: src_key,
        opts: opts
      ]

      Sandbox.apply(@registry, __MODULE__, :copy_object, dest_bucket, binding)
    end

    def set_copy_object_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :copy_object, entries)
    end

    def copy_parts_response(
          dest_bucket,
          dest_key,
          src_bucket,
          src_key,
          upload_id,
          content_length,
          opts
        ) do
      binding = [
        dest_bucket: dest_bucket,
        dest_key: dest_key,
        src_bucket: src_bucket,
        src_key: src_key,
        upload_id: upload_id,
        content_length: content_length,
        opts: opts
      ]

      Sandbox.apply(@registry, __MODULE__, :copy_parts, dest_bucket, binding)
    end

    def set_copy_parts_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :copy_parts, entries)
    end
```

- [ ] **Step 4: Rewrite the 1 shape-E operation**

```elixir
    def list_buckets_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :list_buckets, :*, binding)
    end

    def set_list_buckets_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :list_buckets, entries)
    end
```

- [ ] **Step 5: Verify the counts and that no old-API calls remain**

```bash
grep -c 'Sandbox.apply(' lib/aws_sdk/s3/sandbox.ex      # expect 27
grep -c 'Sandbox.register(' lib/aws_sdk/s3/sandbox.ex   # expect 27
grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/s3/sandbox.ex
```

Expected: 27, 27, and no output from the last command.

- [ ] **Step 6: Run the tests**

Run: `mix test test/aws_sdk/s3/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 7: Format and commit**

```bash
mix format
git add lib/aws_sdk/s3/sandbox.ex
git commit -m "refactor: migrate S3 sandbox to Sandbox.apply/5

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Migrate `AwsSdk.IAM.Sandbox`

**Files:**
- Modify: `lib/aws_sdk/iam/sandbox.ex` (47 operations: A=37, E=10)
- Test: `test/aws_sdk/iam/sandbox_test.exs` (existing, do not modify)

**Interfaces:**
- Consumes: `AwsSdk.Sandbox.apply/5`, `AwsSdk.Sandbox.register/4` from Task 1

The largest module — 47 operations, 801 lines.

- [ ] **Step 1: Run the existing tests to confirm they pass before the change**

Run: `mix test test/aws_sdk/iam/sandbox_test.exs`

Expected: PASS. Note the test count.

- [ ] **Step 2: Add the alias**

After the `@registry :aws_iam_sandbox` attribute, add:

```elixir
    alias AwsSdk.Sandbox
```

- [ ] **Step 3: Rewrite the 37 shape-A operations**

The key is the **first parameter**, `binding` lists every parameter including `opts` in declaration order, and the key is written inline:

```elixir
def <op>_response(p1, p2, opts) do
  binding = [p1: p1, p2: p2, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, p1, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked examples from this file:

```elixir
    def create_user_response(name, opts) do
      binding = [name: name, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :create_user, name, binding)
    end

    def set_create_user_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :create_user, entries)
    end

    def attach_role_policy_response(role, policy_arn, opts) do
      binding = [role: role, policy_arn: policy_arn, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :attach_role_policy, role, binding)
    end

    def set_attach_role_policy_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :attach_role_policy, entries)
    end

    def get_policy_version_response(arn, version_id, opts) do
      binding = [arn: arn, version_id: version_id, opts: opts]

      Sandbox.apply(@registry, __MODULE__, :get_policy_version, arn, binding)
    end

    def set_get_policy_version_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :get_policy_version, entries)
    end
```

- [ ] **Step 4: Rewrite the 10 shape-E operations**

These take no inputs: `get_user`, `list_users`, `create_access_key`, `list_access_keys`, `list_groups`, `list_roles`, `list_policies`, `list_mfa_devices`, `list_open_id_connect_providers`, `get_account_summary`.

```elixir
def <op>_response(opts) do
  binding = [opts: opts]

  Sandbox.apply(@registry, __MODULE__, :<op>, :*, binding)
end

def set_<op>_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :<op>, entries)
end
```

Worked example — note `get_user` takes no positional input because the user name arrives through `opts`:

```elixir
    def get_user_response(opts) do
      binding = [opts: opts]

      Sandbox.apply(@registry, __MODULE__, :get_user, :*, binding)
    end

    def set_get_user_responses(entries) do
      Sandbox.register(@registry, __MODULE__, :get_user, entries)
    end
```

- [ ] **Step 5: Verify the counts and that no old-API calls remain**

```bash
grep -c 'Sandbox.apply(' lib/aws_sdk/iam/sandbox.ex      # expect 47
grep -c 'Sandbox.register(' lib/aws_sdk/iam/sandbox.ex   # expect 47
grep -n 'doc_examples\|find!\|apply_func\|normalize_no_key\|set_responses' lib/aws_sdk/iam/sandbox.ex
```

Expected: 47, 47, and no output from the last command.

- [ ] **Step 6: Run the tests**

Run: `mix test test/aws_sdk/iam/sandbox_test.exs && mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 7: Format and commit**

```bash
mix format
git add lib/aws_sdk/iam/sandbox.ex
git commit -m "refactor: migrate IAM sandbox to Sandbox.apply/5

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: Delete the old primitives

**Files:**
- Modify: `lib/aws_sdk/sandbox.ex` (delete the deprecated block)

**Interfaces:**
- Consumes: nothing new
- Produces: final public API — `start_link/1`, `register/4`, `apply/5`, `disable/2`, `disabled?/2`

- [ ] **Step 1: Verify every sandbox module has migrated**

```bash
grep -rn 'doc_examples\|find!\|apply_func\|normalize_no_key\|Sandbox.set_responses' lib/aws_sdk/*/sandbox.ex
grep -rn 'AwsSdk.Sandbox.find!\|AwsSdk.Sandbox.apply_func\|AwsSdk.Sandbox.doc_examples\|AwsSdk.Sandbox.normalize_no_key\|AwsSdk.Sandbox.set_responses' lib test
```

Expected: no output from either command. If anything is listed, that module was missed — migrate it before continuing.

Also confirm the totals across all eleven modules:

```bash
grep -rc 'Sandbox.apply(' lib/aws_sdk/*/sandbox.ex | awk -F: '{s+=$2} END {print "apply:", s}'
grep -rc 'Sandbox.register(' lib/aws_sdk/*/sandbox.ex | awk -F: '{s+=$2} END {print "register:", s}'
```

Expected: `apply: 232` and `register: 232`.

- [ ] **Step 2: Delete the deprecated block**

In `lib/aws_sdk/sandbox.ex`, delete this entire section — the comment banner and all five functions (`set_responses/4`, `normalize_no_key/1`, `find!/5`, `apply_func/3`, `doc_examples/1`):

```elixir
    # -------------------------------------------------------------------------
    # Deprecated primitives — retained until every sandbox module is migrated
    # to apply/5 and register/4, then deleted.
    # -------------------------------------------------------------------------
```

through to the end of `doc_examples/1`, stopping before the `# Lookup` banner.

- [ ] **Step 3: Compile to confirm nothing referenced them**

Run: `MIX_ENV=test mix compile --warnings-as-errors --force`

Expected: clean compile, no warnings. An "undefined function" error here means a call site was missed in Step 1.

- [ ] **Step 4: Run the full suite**

Run: `mix test`

Expected: PASS, 387 tests, 0 failures.

- [ ] **Step 5: Confirm the size reduction**

```bash
cat lib/aws_sdk/*/sandbox.ex | wc -l
```

Expected: roughly 2,200 lines, down from the 4,371 baseline. Treat a result above 2,600 as a signal that some module still carries the old three-call shape and should be re-checked.

- [ ] **Step 6: Format and commit**

```bash
mix format
git add lib/aws_sdk/sandbox.ex
git commit -m "refactor: drop the pre-apply/5 sandbox primitives

find!/5, apply_func/3, doc_examples/1, normalize_no_key/1 and
set_responses/4 have no callers now that all eleven sandbox modules use
apply/5 and register/4.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Verification checklist

After Task 13, all of the following must hold:

- [ ] `mix test` — 387 tests, 0 failures
- [ ] `MIX_ENV=test mix compile --warnings-as-errors --force` — clean
- [ ] `mix format --check-formatted` — clean
- [ ] `grep -rc 'Sandbox.apply(' lib/aws_sdk/*/sandbox.ex` sums to 232
- [ ] `grep -rc 'Sandbox.register(' lib/aws_sdk/*/sandbox.ex` sums to 232
- [ ] `grep -rn 'binding()' lib/aws_sdk/` returns nothing — the keyword lists are hand-written
- [ ] `grep -rn '"\*"' lib/aws_sdk/*/sandbox.ex lib/aws_sdk/sandbox.ex` returns nothing — the string sentinel is gone
- [ ] No file under `test/` changed except `test/test_helper.exs` and the new `test/aws_sdk/sandbox_test.exs`
- [ ] `cat lib/aws_sdk/*/sandbox.ex | wc -l` is roughly 2,200

## Out of scope

Deliberately excluded — each is a separate design:

- The facade's 243 `defdelegate sandbox_*` and 165 `raise` stubs, which exist because every facade repeats the `Code.ensure_loaded?(SandboxRegistry)` compile-time branch.
- The eleven copies of `build_operation/3`, `apply_overrides/2` and `sandbox?/1`.
- The `Process.sleep/1` in `register/4`.
- The `if sandbox?(opts)` wrapper on each of the 224 facade operations, which stays hand-written — collapsing it would require generating function heads.
