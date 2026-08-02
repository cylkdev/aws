# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
mix compile          # compile (warnings-as-errors in non-test envs)
mix test             # run all tests
mix test <file>      # run a single test file, e.g. mix test test/aws/s3/sandbox_test.exs
mix format           # format code
mix docs             # generate documentation
```

## Architecture

This library wraps AWS services (S3, EventBridge, CloudWatch Logs, IAM, STS, IAM Identity Center, Organizations) with consistent error handling, response deserialization, and sandbox support for testing.

### Service modules

Each service (`AWS.S3`, `AWS.EventBridge`, `AWS.Logs`, `AWS.IAM`, `AWS.STS`, `AWS.IdentityCenter`, `AWS.Organizations`) follows the same structure:

- **Every input AWS requires for an operation is a positional argument.** `opts` (always last, always `\\ []`) carries only optional inputs plus credentials, region, endpoint overrides, and the sandbox flag. Requiredness is enforced by pattern match / guard on the function head (`when is_binary(arn)`), never by a runtime `require_opts!`-style check on the keyword list. When AWS requires *one of* two mutually exclusive inputs, expose two distinct named functions rather than one polymorphic head — e.g. `AWS.ElasticLoadBalancingV2.describe_rules/2` (by listener ARN) vs `describe_rules_by_arns/2` (by rule ARNs), which send different wire params.
- Public functions check `sandbox?/1` first; if true, delegate to the `Sandbox` module
- Otherwise call `do_*` private functions that dispatch through the service's `Client` module, then pipe through `deserialize_response/3`
- Every service's `Client` module is a thin wrapper over `AWS.Client`, the shared dispatcher that owns SigV4 signing, HTTP dispatch (`AWS.HTTP`), credential/endpoint/sandbox resolution, and status-code branching. Per-service clients contribute only the protocol-specific pieces: body encoding (JSON / form-urlencoded / passthrough), request headers (X-Amz-Target for JSON 1.1; Action+Version for Query; per-operation for REST/XML), and URL composition (only S3 needs custom addressing). There is no ExAws integration.
- Wire protocols per service (these are AWS's protocols, not this library's choice — see each module's `@moduledoc` for the authoritative botocore model reference):
  - JSON 1.1: `AWS.EventBridge`, `AWS.Logs`, `AWS.IdentityCenter` (both `sso-admin` and `identitystore`), `AWS.Organizations`
  - Query (form-urlencoded request / XML response): `AWS.IAM`, `AWS.STS` (the internal `AWS.Credentials.Providers.AssumeRole` provider routes its `AssumeRole` call through `AWS.STS.assume_role/4` with pre-resolved source credentials), `AWS.EC2`, `AWS.AutoScaling`, `AWS.ElasticLoadBalancingV2`. Note `AWS.EC2` builds params with `put_member_list/3` + `put_filters/2` and parses inline, while `AWS.AutoScaling` and `AWS.ElasticLoadBalancingV2` share a recursive `flatten_query/1` and extracted `parse_*/1` functions — match the conventions of the module you are editing.
  - REST/XML: `AWS.S3` (virtual-hosted addressing, per-operation response shapes, query-string presigning, streaming bodies)
  - XPath extraction for XML services happens in the service module via `SweetXml`. AWS exposes no JSON alternative for S3, IAM, or STS, so the XML handling is required.
- `AWS.IdentityCenter` covers two sub-services (`sso-admin` and `identitystore`) through one client. `AWS.Organizations` and `AWS.IAM` are global services pinned to `us-east-1` for SigV4 signing.
- `AWS.S3` is the only service with presigned URLs and streaming request/response bodies, backed by `AWS.Signer.sign_query/5` / `presign_post_policy/4` and `AWS.HTTP.stream_upload/5` / `stream_download/3`.

### Sandbox pattern

Each service has a `Sandbox` module backed by `SandboxRegistry` (optional dep, `:dev`/`:test` only). Responses are stored as lists of functions keyed by test PID. Sandbox functions support variable arity: `fn -> result end`, `fn key -> result end`, etc. The registry lookup key is the operation's first positional argument (so `set_*_responses` takes `{key_or_regex, fun}` tuples); operations with no required input key off `"*"` and accept a bare `fn`.

Activate with `sandbox: [enabled: true]` on any per-call opts (or set `config :aws, :sandbox, enabled: true`). When enabled, the public function delegates to the service's `Sandbox` module instead of making an HTTP call. There is no other sandbox mode.

`test/test_helper.exs` starts the sandboxes and `AWS.Counter` (ETS-based call counter for test assertions).

### Serialization

Response deserialization is delegated to `ExUtils.Serializer.deserialize/1` (from the `:ex_utils` git dep), which recursively transforms map keys to snake_case atoms. `ExUtils.Strings` is configured with `to_existing_atom: false, strict: false` in `config/config.exs`, which disables atom-safety so unknown response keys are converted via `String.to_atom/1` rather than `String.to_existing_atom/1`. This matches the previous `AWS.Serializer` behavior; tightening it would require an explicit `:allowed_keys` allowlist.

### Error handling

`AWS.Error` delegates to the `ErrorMessage` library. HTTP 4xx → `not_found`, 5xx → `service_unavailable`, other failures → `internal_server_error`. The adapter is configurable via `config :aws, :error_message_adapter`.

### Configuration

`AWS.Config` resolves each key from per-call opts, then the application environment (`:aws`), then a built-in source chain. Key config keys: `:region`, `:access_key_id`, `:secret_access_key`, `:sandbox` (a keyword list with `:enabled`).

Passing `profile: "name"` in per-call opts resolves every credential key and the region from that named shared-config profile, skipping the built-in chains entirely — so nothing is read from the system or application environment. Precedence is **explicit key opt > `:profile` > app env > built-in defaults**.

### S3 specifics

- `AWS.S3.Multipart` manages multipart uploads with configurable `max_size` (aborts if exceeded)
- `AWS.S3.XMLParser` parses S3 notification XML configs using SweetXml
- `AWS.S3.Sandbox` supports bucket-scoped responses using exact strings or regex patterns for bucket matching
