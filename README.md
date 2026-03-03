# AWS

`AWS` provides a simplified, stateless API for interacting with AWS services.

## Why another AWS library?

For convenience and consistency across projects. This library handles all the
internal complexity of working with AWS and ExAws, allowing you to focus on
your application logic.

This library aims to:

  - **Simplify AWS operations** by abstracting ExAws complexity behind a
    clean, consistent interface across all supported services.

  - **Standardize error handling** by transforming HTTP status codes and
    network errors into structured AWS.Error responses.

  - **Enable sandbox testing** by supporting both local emulated services
    (like LocalStack) and inline OTP-based mocking.

  - **Provide flexible configuration** through a unified options system
    that allows per-call overrides of region, credentials, and sandbox
    settings.

  - **Maintain statelessness** by requiring all necessary configuration to
    be passed explicitly or retrieved from AWS.Config on each call.

This design prioritizes developer experience by offering sensible defaults
while allowing granular control when needed, making it suitable for both
production AWS environments and local development workflows.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `aws` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aws, "~> 0.1.0"}
  ]
end
```