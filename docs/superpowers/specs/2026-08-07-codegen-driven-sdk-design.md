# Data-driven code generation for AwsSdk

Date: 2026-08-07

## Problem

The library is nine hand-written service modules totalling ~25,000 lines. Per
operation, the same facts are restated in six places: the facade signature, the
`@spec`, the `## Arguments` doc block, the `do_*` param map, the two `Sandbox`
functions, and (where one exists) the mix task. Per service, seven helpers are
byte-identical copies. Across the repo, three separate implementations flatten
query params and 690 `~x` sigils repeat the same handful of selector shapes.

None of this duplication carries judgment. All of it can be derived from a
description of the operation plus the AWS service model.

## Decisions

1. **Generation, not metaprogramming.** No `use`, no injected callbacks, no
   runtime interpretation of operation data. The only macro is a Mix task that
   emits ordinary Elixir source. Generated code reads like the hand-written code
   it replaces: greppable, with stack traces pointing at real lines.
2. **The generator owns `lib/aws_sdk/<service>.ex`.** Regeneration overwrites
   it. Nothing in a generated file is hand-edited.
3. **Input side curated, output side derived.** Which inputs are positional and
   in what order, which optionals are exposed, and the sandbox key are curation
   the AWS model cannot express. Response parsing is derived wholesale from the
   model and is never hand-editable.
4. **Docs are template-rendered.** Fixed templates fix the wording across all
   operations; only the slot values differ. No per-operation prose is authored.
5. **S3 is in scope**, including a request sub-language for per-operation URLs,
   verbs, and parameter locations.
6. **Structs over tuples** throughout the codegen data model.

## Data model

All structs live under `AwsSdk.Codegen`.

### Service

```elixir
%AwsSdk.Codegen.Service{
  module: AwsSdk.AutoScaling,
  signing_name: "autoscaling",
  protocol: :query,                    # :json_1_1 | :query | :ec2 | :rest_xml
  api_version: "2011-01-01",
  target_prefix: nil,                  # :json_1_1 only
  endpoint: %AwsSdk.Codegen.Endpoint{},
  registry: :aws_auto_scaling_sandbox,
  operations: [%AwsSdk.Codegen.Operation{}]
}
```

### Endpoint

```elixir
%AwsSdk.Codegen.Endpoint{
  host: "autoscaling.{region}.amazonaws.com",   # {region} interpolated
  region: nil,              # nil = resolved from config; binary = pinned
  default_region: "us-east-1",
  override_key: :auto_scaling
}
```

One field carries the regional/global distinction rather than a tag plus a
payload. `region: nil` means the caller's configured region fills both the host
template and the SigV4 scope. A binary pins both:

```elixir
# AwsSdk.IAM
%AwsSdk.Codegen.Endpoint{host: "iam.amazonaws.com", region: "us-east-1",
                         default_region: "us-east-1", override_key: :iam}

# AwsSdk.Organizations
%AwsSdk.Codegen.Endpoint{host: "organizations.{region}.amazonaws.com", region: "us-east-1",
                         default_region: "us-east-1", override_key: :organizations}
```

This closes by construction the bug documented at `lib/aws_sdk/organizations.ex`
in `build_operation/3`: a `profile:` carrying a region produced
`organizations.<that-region>.amazonaws.com`, which does not resolve. A pinned
`region` is the only value that can reach the host template.

### Operation

```elixir
%AwsSdk.Codegen.Operation{
  action: "DescribeInstanceRefreshes",
  name: :describe_instance_refreshes,
  summary: "Describes instance refreshes for an Auto Scaling group.",
  args: [%AwsSdk.Codegen.Argument{}],       # positional, in order
  opts: [%AwsSdk.Codegen.Option{}],         # curated subset of model optionals
  sandbox_key: :asg,                        # an arg name, or :*
  mix_task: false,
  request: %AwsSdk.Codegen.Request{},
  response: %AwsSdk.Codegen.Response{}
}
```

`args` is the single source of the function signature. The guard, `@spec`, the
`## Arguments` doc block, the sandbox `binding` keyword list, the sandbox
delegate arity, and the mix task are all rendered from it.

### Argument and Option

```elixir
%AwsSdk.Codegen.Argument{
  name: :key, wire: "Key", type: :string, location: :uri,
  doc: "the object key", example: "reports/2026-08.csv"
}

%AwsSdk.Codegen.Option{
  name: :storage_class, wire: "x-amz-storage-class", type: :string, location: :header,
  doc: "storage class for the object"
}
```

`location` ∈ `:body | :uri | :query | :header | :header_prefix`. For the eight
non-S3 services every member is `:body`. `:header_prefix` covers `x-amz-meta-*`,
where the option's value is a map and `wire` is the prefix.

### Field

One struct serves both directions: the response compiler turns a field list into
SweetXml selectors; the request compiler turns the same field list into an XML
document.

```elixir
%AwsSdk.Codegen.Field{
  name: :percentage_complete,
  wire: "PercentageComplete",
  type: :integer,          # :string | :integer | :boolean | :datetime | :json | :structure
  cardinality: :one,       # :one | :many
  optional: true,
  fields: []               # non-empty only when type: :structure
}
```

`type`, `cardinality` and `optional` determine the emitted sigil exactly, with no
remaining special cases:

| type | cardinality | optional | emitted |
|---|---|---|---|
| `:string` | `:one` | `false` | `~x"./Wire/text()"s` |
| `:string` | `:one` | `true` | `~x"./Wire/text()"os` + `nilify/1` |
| `:integer` | `:one` | `true` | `~x"./Wire/text()"oi` |
| `:string` | `:many` | — | `~x"./Wire/text()"sl` |
| `:structure` | `:one` | `true` | `[~x"./Wire"o, ...]` |
| `:structure` | `:many` | — | `[~x"./Wire"l, ...]` |

This vocabulary is provably sufficient: every `~x` sigil in the repo uses only
`s`, `os`, `i`, `oi`, `l`, `sl`, `ls`, `o`, `e`; and the only two post-XPath
transforms in 25,000 lines — `AwsSdk.STS`'s `Expiration` to `DateTime` and
`AwsSdk.IdentityCenter`'s `inline_policy` JSON decode — are leaf types under it.

`{:structure, cardinality: :one, optional: true}` compiles to the anchored `o`
form, so an absent sub-structure is `nil` rather than a map of empty strings.
`optional: true` on a scalar emits the `nilify/1` call, encoding once the fact
that SweetXml's `os` yields `""` and not `nil`.

`fields` is an ordered list, not a map, so generated output is deterministic and
diffable across runs.

### Response

```elixir
%AwsSdk.Codegen.Response{
  strategy: :xpath,        # :xpath | :deserialize | :empty
  root: "//DescribeInstanceRefreshesResult",
  fields: [%AwsSdk.Codegen.Field{}]
}
```

`:deserialize` covers the JSON-1.1 services, handing the body to
`ExUtils.Serializer`. `:empty` covers operations returning `{:ok, %{}}` on an
empty body, such as `CompleteLifecycleAction`.

### Request

```elixir
# AwsSdk.S3.put_object/4
%AwsSdk.Codegen.Request{method: :put, path: "/{key}", addressing: :virtual_host,
                        body: :stream, fields: []}

# AwsSdk.S3.put_bucket_encryption/2
%AwsSdk.Codegen.Request{method: :put, path: "/", addressing: :virtual_host,
                        body: :xml, fields: [%AwsSdk.Codegen.Field{}]}

# every operation of the eight non-S3 services
%AwsSdk.Codegen.Request{method: :post, path: "/", addressing: :path,
                        body: :form, fields: []}
```

`body` ∈ `:none | :form | :json | :xml | :stream | :raw`, and is the only thing
deciding how params become bytes. `body: :stream` sets `stream_upload: true` on
the `%AwsSdk.Operation{}`; a streaming response sets `stream_response: true`.

`addressing` ∈ `:path | :virtual_host`.

Accepted wart: `addressing: :virtual_host` serves exactly one service and
`:header_prefix` roughly one operation, yet both fields are carried by every
operation. This is the price of bringing S3 in scope, taken in exchange for the
XMLBuilder/parser unification above.

## Sources

Two files per service, neither of which is both hand-edited and machine-written.
There is therefore no merge or round-trip problem.

**`models/<service>.json`** — the AWS SDK Go v2 service model, vendored verbatim
and pinned, never edited. Lives at the repo root, excluded from the hex package,
since generation is a dev-time activity. `mix aws_sdk.models.refresh` re-pulls
them.

This is what `aws-beam/aws-codegen` contributes. Not its templates — those render
the `AWS.S3.list_buckets(%AWS.Client{}, input)` shape, which is the opposite of
this library's API. What is valuable is the model corpus it consumes and its
protocol taxonomy, which lines up 1:1 with this library's four protocols.

**`priv/specs/<service>.exs`** — pure curation, hand-owned, evaluating to an
`%AwsSdk.Codegen.Service{}`. Per operation it carries only what the model cannot
express: `action`, `name`, `summary`, `args` and their order, the curated `opts`
subset, `sandbox_key`, `mix_task`.

`mix aws_sdk.gen` reads both. Everything derivable comes from the model at
generation time, with no intermediate file:

| Field | Source |
|---|---|
| `args[].wire`, `opts[].wire`, `.type`, `.location` | model member `locationName`, shape type, `location` |
| `request` | model `http` block and member locations |
| `response` | model output shape, in full |
| `signing_name`, `api_version`, `target_prefix`, `protocol` | model `metadata` |

`response` is derived and never hand-editable, which follows from the response
fidelity rules in `CLAUDE.md` rather than from convenience. Rule 4 (nothing
dropped) fixes the field set as exactly the model's output shape. Rule 5
(envelope dropped) gives `root`. Rules 1–3 fix nesting, naming and list handling
mechanically. Leaf coercion follows the model's declared types. No judgment
remains in a parser to preserve.

### Tooling

- `mix aws_sdk.gen` — regenerate all services.
- `mix aws_sdk.gen --check` — regenerate to a temp tree and fail on any diff.
  Catches a hand-edit to a generated file, or a stale checkout, in CI.
- `mix aws_sdk.gen --report-uncurated` — list model optionals absent from every
  spec. Curated `opts` is a subset by design, so spec and model can diverge in
  coverage silently; this makes the divergence inspectable.
- `mix aws_sdk.scaffold <service> <Action>` — print an
  `%AwsSdk.Codegen.Operation{}` entry with all model optionals in `opts`,
  required members as `args` in model order, and `sandbox_key` defaulted to the
  first arg, for pasting into the spec and trimming. It never rewrites a file
  that is hand-edited.

Validation falls out for free: if a spec's `args`/`opts` name a member the model
does not have, `mix aws_sdk.gen` fails rather than emitting a wrong wire name.
An AWS rename or removal becomes a build error instead of a runtime 400.

## Shared runtime

Hand-written ordinary modules, called explicitly from generated code. No
callbacks, no `use`, nothing injected — a reader follows the call.

| Module | Absorbs |
|---|---|
| `AwsSdk.Query.encode/2` *(exists)* | `flatten_query/1` in `auto_scaling.ex` and `elastic_load_balancing_v2.ex`; `put_member_list/3` and `put_filters/2` in `ec2.ex` |
| `AwsSdk.Params` *(new)* | `maybe_put/3`, `nilify/1` |
| `AwsSdk.Body` *(new)* | `encode_body/1`, `decode_body/1`, `deserialize_opts/1`, `@deserialize_defaults` |
| `AwsSdk.Sandbox.enabled?/3` *(new)* | the nine byte-identical `sandbox?/1` clauses |
| `AwsSdk.Protocol.{Json,Query,Ec2,RestXml}` *(new)* | the nine `build_operation/3` bodies, one per protocol |

`AwsSdk.Protocol.Query.build(action, params, endpoint, opts)` returns
`{:ok, %AwsSdk.Operation{}}`.

Three S3 concerns are not operations and stay hand-written, calling generated
functions:

- `AwsSdk.S3.Multipart` — orchestration across `CreateMultipartUpload`,
  `UploadPart` and `CompleteMultipartUpload` with `max_size` enforcement and
  abort-on-exceed. Policy, not a wire shape.
- `AwsSdk.HTTP.stream_upload/5` and `stream_download/3` — transport, already
  shared.
- `AwsSdk.Signer.sign_query/5` and `presign_post_policy/4` — signing primitives.

The presign *entry points* are generated. `presigned_url(bucket, key, opts)`
needs exactly `method`, `path`, `addressing` and the `:query`-located params, all
of which `%AwsSdk.Codegen.Request{}` already carries. Today presigning restates
S3's URL composition a second time; reading from the same struct as the live call
means a presigned URL cannot disagree with the request it stands in for.

## Generated output

Per service:

```
lib/aws_sdk/<service>.ex              # moduledoc, per-op @doc/@spec/facade/do_/parse_
lib/aws_sdk/<service>/sandbox.ex      # two functions per op, rendered from args
lib/mix/tasks/aws_sdk/<service>/      # only where the operation sets mix_task: true
```

Mix tasks exist today for roughly 40 of ~200 operations. Generating all of them
would be noise, so `mix_task: true` opts in.

For the `%AwsSdk.Codegen.Operation{}` above, the generator emits:

```elixir
  @doc """
  Describes instance refreshes for an Auto Scaling group.

  Maps to AWS `DescribeInstanceRefreshes`.

  ## Arguments

    * `asg` - the Auto Scaling group name

  ## Options

    * `:max_records` - page size

  See `AwsSdk.AutoScaling` shared options for credentials / region / endpoint.

  ## Examples

      AwsSdk.AutoScaling.describe_instance_refreshes("web-asg")
      #=> {:ok,
      #=>  %{
      #=>    instance_refreshes: [
      #=>      %{
      #=>        instance_refresh_id: "08b91cf7-8fa6-48af-b6a6-d227f40f1b9b",
      #=>        percentage_complete: 50,
      #=>        start_time: ~U[2026-08-07 00:00:00Z],
      #=>        preferences: %{min_healthy_percentage: 90, skip_matching: false}
      #=>      }
      #=>    ],
      #=>    next_token: nil
      #=>  }}
  """
  @spec describe_instance_refreshes(String.t(), keyword) :: {:ok, map} | {:error, term}
  def describe_instance_refreshes(asg, opts \\ []) when is_binary(asg) do
    if AwsSdk.Sandbox.enabled?(@registry, __MODULE__, opts) do
      sandbox_describe_instance_refreshes_response(asg, opts)
    else
      do_describe_instance_refreshes(asg, opts)
    end
  end

  defp do_describe_instance_refreshes(asg, opts) do
    params =
      AwsSdk.Query.encode(%{
        "AutoScalingGroupName" => asg,
        "MaxRecords" => opts[:max_records]
      }, :query)

    with {:ok, op} <- AwsSdk.Protocol.Query.build("DescribeInstanceRefreshes", params, @endpoint, opts),
         {:ok, %{body: body}} <- AwsSdk.Client.request(op) do
      {:ok, parse_describe_instance_refreshes(body)}
    end
  end
```

The `## Arguments`, `## Options` and `## Examples` blocks come from fixed
templates: identical wording across all operations, only the slots differ. The
`#=>` block is rendered by walking the same `%AwsSdk.Codegen.Field{}` list the
parser is compiled from, filling leaves from `example:` values, so a doc example
that disagrees with the parser is unrepresentable.

Generated files carry a `# Generated by mix aws_sdk.gen — do not edit` header and
must come out `mix format`-clean and clean under warnings-as-errors.

## Phases

**Phase 0 — extract the shared runtime, no generator.** Hand-write
`AwsSdk.Params`, `AwsSdk.Body`, `AwsSdk.Sandbox.enabled?/3` and
`AwsSdk.Protocol.*`; fold the three query-flatteners into
`AwsSdk.Query.encode/2`; refactor all nine services to call them. `mix test`
passes untouched. Worth doing on its own merits even if the generator never
ships, and it shrinks what the generator must reproduce.

**Phase 1 — characterization tests.** Must precede any generation.

`conformance_test.exs` holds its XML inline and covers a thin slice. The sandbox
tests are explicitly no help: they assert against fixtures they register
themselves, so they prove nothing about a parser. There is currently no oracle
for "did the generated parser produce what the hand-written one produced."

Promote fixtures to files at `test/fixtures/<service>/<Action>.xml`, captured
from real AWS responses, one per operation, and assert the hand-written parser's
exact output. Those assertions are the contract the generator must satisfy.

**Phase 2 — the compiler, and one service.** Build the `AwsSdk.Codegen` structs
and the field-list-to-SweetXml compiler, unit-tested in isolation. Then
`AwsSdk.AutoScaling`: 12 operations, query protocol, 1,339 lines, no S3
irregularities. Write its spec, generate, diff against the hand-written module,
iterate. Delete the hand-written file only once Phase 1's conformance cases pass.

**Phase 3 — roll forward** in ascending complexity: `AwsSdk.ElasticLoadBalancingV2`,
`AwsSdk.Logs`, `AwsSdk.SSM`, `AwsSdk.EventBridge`, `AwsSdk.Organizations`,
`AwsSdk.IdentityCenter`, `AwsSdk.STS`, `AwsSdk.IAM`, `AwsSdk.EC2`.

**Phase 4 — S3**, with the request sub-language, XMLBuilder unification via the
shared `%AwsSdk.Codegen.Field{}` compiler, and generated presign entry points.

## Risks

**Generated parsers will return strictly more fields than the hand-written ones,
and that is the intended outcome.** Rule 4 says nothing documented is dropped;
the current parsers were hand-picked and some do drop members. Generating from
the model's full output shape fixes those conformance defects — which means Phase
1's characterization assertions will start failing the moment generation begins.

"Diff-free against today's output" is therefore the wrong acceptance bar, and
adopting it would silently re-enshrine the defects. The bar is: every difference
is triaged individually, and each is either a member AWS documents that was being
dropped (accept — it is the fix) or a compiler defect (fix the compiler). This
triage is the actual work of Phase 3, not a rubber stamp, and should be budgeted
per service.

**`:datetime` coercion is a behaviour change.** `auto_scaling.ex` currently
returns `created_time` as a raw string; the model types it as a timestamp, so the
generator emits a `DateTime`. Correct per the coercion rule, but it breaks any
caller pattern-matching on the binary.

**The Go v2 models are a moving pin.** Refreshing them can change a wire name or
add a required member, changing generated code across services at once.
`mix aws_sdk.gen --check` in CI turns that into a visible failure rather than a
surprise.
