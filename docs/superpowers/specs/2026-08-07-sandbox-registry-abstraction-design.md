# Sandbox registry abstraction

**Date:** 2026-08-07
**Status:** approved, not yet implemented
**Scope:** `AwsSdk.Sandbox` and the eleven `AwsSdk.<Service>.Sandbox` modules

This is the first of the abstractions identified across the codebase. It covers
only the sandbox modules. The facade-side sandbox plumbing (243 `defdelegate`s
and 165 `raise` stubs) and the per-service transport preamble
(`build_operation/3`, `apply_overrides/2`, `sandbox?/1`, eleven copies each) are
separate designs.

## Problem

`mix xref` shows the dependency structure is already clean: every facade depends
on exactly `AwsSdk.Client` and `AwsSdk.Config`, there are no cycles among
facades, and `Client` / `Operation` / `Sandbox` are already shared. The
duplication is not architectural. It is textual — the same shape retyped 232
times.

Every sandbox operation is two functions, and every one of the 232 composes the
same four primitives in the same fixed order:

```elixir
def describe_instance_refreshes_response(asg, opts) do
  examples = AwsSdk.Sandbox.doc_examples([:asg])

  func =
    AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_instance_refreshes, asg, examples)

  AwsSdk.Sandbox.apply_func(func, [asg, opts], examples)
end

def set_describe_instance_refreshes_responses(tuples) do
  AwsSdk.Sandbox.set_responses(
    @registry,
    __MODULE__,
    :describe_instance_refreshes,
    AwsSdk.Sandbox.normalize_no_key(tuples)
  )
end
```

The variation across all 232 was measured, not assumed:

- `apply_func`'s args are always exactly the function's own parameters, in order.
- `doc_examples`' names are always exactly the positional parameter names.
- `normalize_no_key` wraps every one of the 232 `set_*_responses` — 232 of 232.
- `find!/5`, `apply_func/3`, `doc_examples/1` and `normalize_no_key/1` are called
  from nowhere outside the sandbox modules.

The only real variation is the lookup key. Eleven modules, 4,371 lines.

### Defects in the current lookup mechanism

The registry matches a single derived string rather than the operation's inputs,
which produces four distinct problems.

**`"*"` is a sentinel disguised as a wildcard.** It never means "any". For an
input-less operation it is a literal key meaning "no input"; for an operation
that has inputs, registering `{"*", fun}` matches only a call whose first input
is the literal string `"*"`. The same token means two different things depending
on the operation, and neither of them is "match anything". `normalize_no_key`
names it correctly — "no key" — while it reads as a glob.

**Only one input can be matched.** 61 of 232 operations take two or more inputs;
every input after the key is invisible to the registry.

**The escape hatches are string mangling.** Nine sites hand-build a key.
`"#{hook}|#{asg}"` invents a `|` delimiter. `Enum.join(arns, ",")` invents a `,`
delimiter and forces the test to know the join order.
`List.first(resource_ids) || "*"` silently falls through to the sentinel.

**The key is forced to be a string** solely because pattern matching calls
`Regex.match?/2` on it — which is the only reason list inputs need joining.

## Design

No macros, no codegen, no new module, no new layer. `AwsSdk.Sandbox` already is
the shared seam; it exposes four primitives that all 232 callers compose in one
fixed order. It is replaced by the composition itself, renamed to the
Elixir/OTP vocabulary it is built on.

The module knows nothing about AWS. It is a process-scoped registry of stub
functions, and after this change nothing in it is named for HTTP, for AWS wire
protocols, or for any particular service.

### Token audit

| Current | Verdict | Replacement |
| --- | --- | --- |
| `action` | Leak. "Action" is the AWS Query-protocol wire parameter (`Action=DescribeInstances`). | `function` — the thing being stubbed is a function, identified module-and-name, the standard Elixir `{module, function}` idiom |
| `name` (in `find!/5`, `find_response!/5`) | Vague, and inconsistent with `lookup_key` elsewhere. | `key` — `Registry.lookup(registry, key)` is the vocabulary this is built on |
| `response` / `set_responses` | Leak. "Response" is HTTP/AWS. The stored value is a function. | `apply` / `register` |
| `find!` | Non-standard. | `fetch!` — Elixir's settled name for get-or-raise (`Map.fetch!`, `Keyword.fetch!`) |
| `apply_func` | Redundant once `apply/5` exists. | folded into `apply/5` |
| `func` | Elixir and Erlang spell it `fun` (`:erlang.fun_info`, `Function`, `fn`). | `fun` |
| `normalize_no_key` | Names a workaround that `:*` removes. | deleted, folded into `register/4` |
| `doc_examples` / `arg_names` | Wordy. | `examples` / `names` |
| `sandbox_key` | Redundant prefix — everything in the module is the sandbox. | `key` |
| `registry`, `module`, `binding`, `args`, `arity`, `state`, `pattern` | Clean. All OTP/Elixir vocabulary — `Registry`, `binding()`, `Kernel.apply/2`, `:erlang.fun_info`, `Regex`. | unchanged |

### Public API

One convention throughout — Elixir data-access and OTP verbs, no bespoke names:

```elixir
start_link(registry)
register(registry, module, function, entries)
apply(registry, module, function, key, binding)
disable(registry, module)
disabled?(registry, module)
```

`fetch!/5`, `examples/1` and the raise helpers are private.

`Sandbox.apply/5` shadows `Kernel.apply/2,3` in name only. Call sites are
qualified, and the single internal use is written `Kernel.apply/2`. Applying a
looked-up function to a list of arguments is exactly what `apply` means, so the
correct verb is worth the shadowing.

### `apply/5`

```elixir
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
```

#### `key`

```elixir
@type key :: String.t() | :*
```

Both halves of the registry key arrive as arguments. Nothing is derived inside
`apply/5`. `nil` is not a valid key — it fails the guard with a
`FunctionClauseError` naming `AwsSdk.Sandbox.apply/5`. Guarding on the function
head is how this library already enforces requiredness.

`:*` replaces `"*"` and means the same thing on both sides of the match: this
applies to every call of the function. It is a distinct type from `String.t()`,
so the two cases differ in kind rather than by convention — a string names one
call, `:*` names all of them.

#### `binding`

The operation's parameters as a keyword list in declaration order, `opts` last.
The names build the `fn` shapes shown in error messages; the values are applied
to the stub positionally.

The list is written out at each call site. `Kernel.binding/0` is **not** used and
must not be: it returns variables sorted alphabetically rather than in
declaration order, which breaks positional application.

```elixir
def three(group, stream, opts), do: binding()
#=> [group: "g", opts: [x: 1], stream: "s"]        # opts in the MIDDLE

def five(dest_bucket, dest_key, src_bucket, src_key, opts), do: binding()
#=> [dest_bucket:, dest_key:, opts:, src_bucket:, src_key:]
```

Taking the first two values from `three`'s binding hands `fn group, stream -> end`
the group and the **opts**. S3's `copy_parts/7` would scramble four of its six
inputs. `binding()` also captures locals and underscored parameters
(`def unused(a, _b, opts), do: binding()` yields `[_b: "b", a: "a", opts: []]`),
so any variable later introduced into one of these functions would silently
become a stub argument.

#### Lookup

Lookup is by `{function, key}`, in three ordered steps:

1. **exact** — a binary key equal to `key`
2. **pattern** — a `Regex` key registered for the same `function` whose pattern
   matches `key`. Skipped unless `key` is a binary, so `Regex.match?/2` is never
   handed an atom.
3. **wildcard** — a response registered under `:*`, matching any call to that
   function

An input-less operation passes `:*` and resolves at step 1. A keyed operation
now also falls through to step 3, which is new: a test can register one response
for every call of a function regardless of its key.

```elixir
Sandbox.set_get_user_responses([
  {"alice", fn -> {:ok, %{user: %{user_name: "alice"}}} end},
  {:*, fn name -> {:error, ErrorMessage.not_found("no such user", %{name: name})} end}
])
```

Today that is impossible — `"*"` registered against a keyed operation matches
only a call whose input is literally `"*"`.

**If several patterns match, which one wins is unspecified.** Register
non-overlapping patterns. This is not a new limitation: responses are stored in
a map, and map iteration is neither insertion order nor sorted order — a 40-key
map registered `1..40` iterates `21, 8, 2, 11, 39, …`. The current code's
`Enum.filter` / `Enum.find` over that map has the same property. The contract is
now stated rather than implied.

#### Return value and raises

`apply/5` returns whatever the stub returns, unaltered — it never inspects or
wraps it. Tests register the service's own shapes:

```elixir
{:ok, %{log_streams: [], next_token: nil}}
{:error, ErrorMessage.not_found("resource not found.", %{status: 404})}
```

The stub is applied at its own arity, so a test writes only the parameters it
cares about. Arity `0` is called with no arguments; any arity up to
`length(binding)` receives that many leading values.

It raises when:

- the registry was never started for `module` — the message points at
  `test_helper.exs`
- the calling process registered no stubs at all
- stubs exist for this process but none match `{function, key}` — the message
  lists what was registered
- a registered value is not a function
- a registered function's arity exceeds `length(binding)`

#### `module` is diagnostic-only

Each service owns its own `@registry`, so the registry key is `{function, key}`.
`module` never participates in lookup; it exists solely to build the error
message. This is documented on the function rather than left to be inferred.

### `register/4`

Signature unchanged from `set_responses/4`. It absorbs the `normalize_no_key/1`
call that all 232 sites made, so raw entries become the only input.

Each entry is a `{key, fun}` tuple, or a bare `fun` — shorthand for `{:*, fun}`.

`key` is an exact binary compared for equality, a `Regex` matched against the
key the operation passes, or `:*`. Registration is scoped to the calling
process — and, because `SandboxRegistry.lookup/2` walks `$callers` and
`$ancestors`, resolves from its descendants too, so code under test may spawn
`Task`s freely. An unrelated process resolves nothing. Registration is
additive:
registering a second function leaves the first in place; registering the same
`{function, key}` twice replaces the earlier stub. Returns `:ok`, sleeping
briefly so the registration is visible before the test proceeds. Raises if the
registry was never started for `module`.

### `examples/1`

Now receives names that already include `:opts`, so it stops appending it, and
its `case` disappears:

```elixir
defp examples(names) do
  first = List.first(names)
  full = Enum.map_join(names, ", ", &to_string/1)

  Enum.uniq(["fn -> ... end", "fn #{first} -> ... end", "fn #{full} -> ... end"])
end
```

For `[:opts]` the last two collapse to one string, which `uniq` removes,
reproducing today's two-example output for input-less operations. Error text
stays byte-identical.

### The one documented convention

`format_example/3` builds `#{module}.set_#{function}_responses([...])`. A generic
registry cannot know that callers name their setters that way.

This is the abstraction's own contract, not AWS knowledge: *register through
`set_<function>_responses/1` on your sandbox module*. It is stated in the
moduledoc, which makes it a documented convention rather than a leak, and it is
what makes the errors actionable. The alternatives — threading the setter name
through all 232 call sites, or degrading the message to "call
`AwsSdk.Sandbox.register/4`" — cost either churn or error quality.

## Call sites

Every operation keeps its own named function head with real parameter names.
Both halves of its registry key are visible at the call site. The `key` is
written at the argument position; it is never aliased into a local variable.

```elixir
def create_user_response(name, opts) do
  binding = [name: name, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :create_user, name, binding)
end

def set_create_user_responses(entries) do
  Sandbox.register(@registry, __MODULE__, :create_user, entries)
end
```

### The four key shapes

All 232 operations, by the shape of the value in the `key` argument position.

**A — an input, verbatim · 167 operations.** The key is one of the operation's
own parameters, passed straight through. It is not always the first parameter;
that is a property of the current code, not a rule. Whichever input identifies
the call goes in the argument.

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
```

**B — two inputs, joined · 2 operations.** `AutoScaling.complete_lifecycle_action`
and `record_lifecycle_action_heartbeat`, where neither input alone identifies the
call.

```elixir
def complete_lifecycle_action_response(hook, asg, result, opts) do
  binding = [hook: hook, asg: asg, result: result, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :complete_lifecycle_action, "#{hook}|#{asg}", binding)
end
```

**C — a list input, joined · 7 operations.** ELBv2
`describe_target_groups_by_names`, `describe_target_groups_by_arns`,
`describe_listeners_by_arns`, `describe_rules_by_arns`; Logs
`start_query_for_log_groups`, `start_query_by_identifiers`; EC2 `create_tags`.
The identifying input is a list, and a list is neither an exact string key nor a
`Regex.match?/2` subject.

```elixir
def describe_target_groups_by_arns_response(arns, opts) do
  binding = [arns: arns, opts: opts]

  Sandbox.apply(@registry, __MODULE__, :describe_target_groups_by_arns,
    Enum.join(arns, ","), binding)
end
```

EC2's `create_tags` joins here for the first time. It currently keys off
`List.first(resource_ids) || "*"`, a shape that existed only because
`List.first/1` returns `nil` on an empty list and `nil` had to become something.
With `nil` now a hard error, it keys off its list the same way the other six do —
`Enum.join([], ",")` is `""`, a binary, so there is no fallback and no special
case.

**E — `:*` · 56 operations.** The operation takes no inputs, so there is nothing
to identify a call by.

```elixir
def list_users_response(opts) do
  binding = [opts: opts]

  Sandbox.apply(@registry, __MODULE__, :list_users, :*, binding)
end
```

167 + 2 + 7 + 56 = 232.

## Data flow

Unchanged. Same registry, same per-PID storage, same arity matching, same raise
sites and — for every path that exists today — the same message text.

## Testing

The existing sandbox tests are the regression suite. They already exercise exact
keys, regex keys, every supported `fn` arity, and both the "nothing registered"
and "no match" raise paths.

**No test changes are required.** All 239 registration call sites keep working:

- 164 register a bare `fn`, which `register/4` normalizes to `{:*, fun}` exactly
  as `normalize_no_key/1` did.
- No test registers a literal `"*"` — the sentinel exists only inside `lib`, at
  56 `find!` sites and in `normalize_no_key`. It is an internal encoding test
  authors never see.
- The only `create_tags` test registers `{"i-1", ...}` and calls
  `create_tags(["i-1"], ...)`. `Enum.join(["i-1"], ",")` is `"i-1"`, so it still
  matches.

Three behaviours are genuinely new and need coverage:

1. `:*` registered against a keyed operation matches any call to it (lookup
   step 3) — impossible today.
2. `nil` as a key raises rather than being looked up.
3. The pattern step is skipped when `key` is `:*`, so `Regex.match?/2` is never
   handed an atom. A regex registered for an input-less operation raises "not
   found" rather than crashing.

## Scale

Eleven modules, 4,371 lines, reduced to roughly 2,200.

## Out of scope

- The facade's 243 `defdelegate sandbox_*` and 165 `raise` stubs, which exist
  because every facade repeats the `Code.ensure_loaded?(SandboxRegistry)`
  compile-time branch.
- The eleven copies of `build_operation/3`, `apply_overrides/2` and `sandbox?/1`.
- The `Process.sleep/1` in `register/4`.
- The public `if sandbox?(opts)` wrapper on each of the 224 facade operations,
  which stays hand-written — collapsing it would require generating function
  heads.
