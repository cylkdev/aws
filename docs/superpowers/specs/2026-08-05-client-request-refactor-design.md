# Design: retire `perform`/`deserialize_response` — explicit call sites, error mapping in Client

Date: 2026-08-05
Status: approved (call-site shape and whole-codebase scope chosen by Kurt)

## Goal

Remove the per-module `perform/2..3` and `deserialize_response/3` private
helpers from every service module. Each operation's `do_*` function becomes
an explicit `with` pipeline the reader can follow at the call site; the
HTTP-status-to-error contract moves into `AwsSdk.Client`, the shared
dispatcher every module already goes through, so it lives in exactly one
documented place instead of eleven copies.

This precedes the NEXT.md backlog
(`docs/superpowers/specs/2026-08-05-nextmd-operations-design.md`) so the new
operations are written in the new style once, never migrated.

## The new seam: `AwsSdk.Client.request/1`

```elixir
@spec request(struct) :: {:ok, map} | {:error, ErrorMessage.t()}
# Success passes execute/1's response map through untouched (body +
# headers today; the plan pins the exact keys after reading dispatch/7).
def request(%_{} = op) do
  case execute(op) do
    {:ok, response} ->
      {:ok, response}

    {:error, {:http_error, status, response}} when status in 400..499 ->
      {:error, ErrorMessage.not_found("resource not found.", %{response: response})}

    {:error, {:http_error, status, response}} when status >= 500 ->
      {:error,
       ErrorMessage.service_unavailable("service temporarily unavailable", %{response: response})}

    {:error, reason} ->
      {:error, ErrorMessage.internal_server_error("internal server error", %{reason: reason})}
  end
end
```

- The error clauses are moved **verbatim** from the modules'
  `deserialize_response/3` — same `ErrorMessage` constructors, same
  messages, same detail maps. Behavior-compatible by construction.
- S3's `deserialize_response` carries one clause the others lack:
  3xx → `ErrorMessage.bad_request("redirect not followed.", ...)`.
  `Client.request/1` includes it, making the contract uniform: 3xx →
  `bad_request`, 4xx → `not_found`, 5xx → `service_unavailable`,
  transport → `internal_server_error`. For the non-S3 modules this is a
  theoretical behavior change (a 3xx previously fell through to
  `internal_server_error`; the JSON/Query AWS APIs do not redirect).
- S3's `normalize_notification_error/2` re-implements the standard
  mapping and exists only because two call sites bypass
  `deserialize_response`; once `s3_request` errors arrive as
  `ErrorMessage`, it is deleted.
- `execute/1` stays as-is (raw transport seam; the signer test and
  streaming paths depend on it).
- Success value is the same response map `execute/1` returns today, so
  call sites that need headers (S3) match `%{headers: headers}` and
  everything else matches `%{body: body}`.

## Call-site shape

Every operation follows this form — nothing hidden between the request
and the return value:

```elixir
defp do_get_parameter(name, opts) do
  data =
    %{"Name" => name}
    |> maybe_put("WithDecryption", opts[:with_decryption])

  with {:ok, op} <- build_operation("GetParameter", data, opts),
       {:ok, %{body: body}} <- Client.request(op) do
    Serializer.deserialize(decode_body(body), deserialize_opts(opts))
  end
end
```

- XML services parse in the success position:
  `{:ok, parse_describe_launch_templates(body)}`.
- Protocol-specific request/response encoding stays in the service
  modules (`decode_body` JSON decoding, `flatten_query`, XML parsers) —
  the refactor moves error mapping only.
- One behavior change, accepted: SSM/EventBridge/Logs/IdentityCenter/
  Organizations today JSON-decode the *error* body before wrapping it in
  the `ErrorMessage` details (`decode_response/1`). After the refactor the
  details carry the response as the transport produced it. Nothing in the
  library or its tests reads decoded error bodies; callers that do can
  decode the `:response` detail themselves.

## What is deleted / rewritten

Per service module (`ssm`, `ec2`, `iam`, `sts`, `auto_scaling`,
`elastic_load_balancing_v2`, `s3`, `event_bridge`, `logs`,
`identity_center`, `organizations`):

- Delete `defp deserialize_response/3` (all clauses) and `defp perform/2..3`
  (and JSON modules' `defp decode_response/1` where its only job was
  routing decoded bodies into `deserialize_response`; the success-path
  `decode_body/1` stays).
- Rewrite every `do_*` function to the `with` pipeline above. The
  operation's params/parsing code is untouched — only the dispatch tail
  changes.
- `sandbox?/1` branches, `Sandbox` modules, `build_operation/3`, and all
  parsers are untouched.

S3 is the exception-heavy module and gets its own pass: `s3_request/4`
(its `perform`-equivalent) and `normalize_notification_error/2` are
deleted along with `deserialize_response/3`; each of the 22 call sites
becomes the explicit `build_operation` + `Client.request` pipeline, with
the old success callback's body (header deserialization, streaming
response handling, embedded `<Error>`-on-200 parsing) moved into the
`with` block. No S3 behavior changes.

One normalization note for every module: the old `deserialize_response`
success clause wrapped bare callback results in `{:ok, _}` and passed
`{:ok, _}`/`{:error, _}` tuples through. When a callback body moves into
a `with` block, that is preserved by hand — bare-value expressions get
an explicit `{:ok, ...}` wrap; tuple-returning expressions are left
alone.

## CLAUDE.md updates

- Architecture bullet "then pipe through `deserialize_response/3`" →
  describes the explicit `with {:ok, op} <- build_operation(...),
  {:ok, %{body: body}} <- Client.request(op)` shape.
- Error-handling section: mapping unchanged (4xx → `not_found`, 5xx →
  `service_unavailable`, other → `internal_server_error`), location now
  `AwsSdk.Client.request/1`.

## Testing

- The existing suite is the regression guard; it must stay green after
  every module's migration.
- New: direct unit tests for `Client.request/1`'s three error mappings
  and success passthrough (the contract now has one home, so it gets one
  test file: `test/aws_sdk/client_test.exs`, extended or created).
- Any existing per-module test that asserted `deserialize_response`
  behavior through a public function keeps passing unchanged — that is
  the point of the verbatim move.

## Migration order (one commit per module, suite green at each)

1. `AwsSdk.Client.request/1` + its tests (additive, nothing calls it yet)
2. SSM (smallest JSON module — proves the JSON shape)
3. EventBridge, Logs, IdentityCenter, Organizations (same JSON shape)
4. EC2 (largest Query/XML)
5. IAM, STS, AutoScaling, ElasticLoadBalancingV2
6. S3 (exception-heavy, last, one clause at a time)
7. CLAUDE.md update

## Follow-up

After this lands, `docs/superpowers/plans/2026-08-05-nextmd-operations.md`
is revised so every task's implementation code uses the new call-site
shape (mechanical edit: `perform(...) |> deserialize_response(...)` tails
become `with` pipelines), then the backlog proceeds.
