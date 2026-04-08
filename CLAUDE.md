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

This library wraps AWS services (S3, EventBridge, CloudWatch) with consistent error handling, response deserialization, and sandbox support for testing.

### Service modules

Each service (`AWS.S3`, `AWS.EventBridge`, `AWS.CloudWatch`) follows the same structure:

- Public functions check `inline_sandbox?/1` first; if true, delegate to the `Sandbox` module
- Otherwise call `do_*` private functions that build the ExAws operation, `perform/2` it, then pipe through `deserialize_response/3`
- `AWS.EventBridge` builds raw `ExAws.Operation.JSON` structs directly (no ex_aws_eventbridge dep); the others delegate to ExAws service libs

### Sandbox pattern

Each service has a `Sandbox` module backed by `SandboxRegistry` (optional dep, `:dev`/`:test` only). Responses are stored as lists of functions keyed by test PID. Sandbox functions support variable arity: `fn -> result end`, `fn key -> result end`, etc.

Two sandbox modes (passed via `sandbox: [enabled: true, mode: :inline | :local]`):
- `:inline` — in-process Registry mock, no HTTP
- `:local` — routes HTTP calls to a local service (e.g., LocalStack on port 4566)

`test/test_helper.exs` starts all three sandboxes and `AWS.Counter` (ETS-based call counter for test assertions).

### Serialization

`AWS.Serializer.deserialize/1` recursively transforms all map keys to snake_case atoms via `Recase`. One special case is inlined: `"e_tag"` normalizes to `"etag"` before snake-casing. `AWS.Utils.transform_keys/2` handles the recursive traversal over maps and lists.

### Error handling

`AWS.Error` delegates to the `ErrorMessage` library. HTTP 4xx → `not_found`, 5xx → `service_unavailable`, other failures → `internal_server_error`. The adapter is configurable via `config :aws, :error_message_adapter`.

### Configuration

`AWS.Config` reads from the application environment (`:aws`). Key config keys: `:region`, `:access_key_id`, `:secret_access_key`, `:sandbox_enabled`, `:sandbox_mode`, `:sandbox_host`, `:sandbox_port`, `:sandbox_scheme`.

### S3 specifics

- `AWS.S3.Multipart` manages multipart uploads with configurable `max_size` (aborts if exceeded)
- `AWS.S3.XMLParser` parses S3 notification XML configs using SweetXml
- `AWS.S3.Sandbox` supports bucket-scoped responses using exact strings or regex patterns for bucket matching
