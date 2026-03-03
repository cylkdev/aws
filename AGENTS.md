# AWS

AWS is a lightweight Elixir library that provides a standardized, stateless API for interacting with Amazon Web Services. Built as a serverless-ready wrapper around the ExAws ecosystem, it delivers consistent error handling, flexible configuration, and comprehensive sandbox support for seamless local development and testing.

## Purpose

The library abstracts the complexity of AWS service interactions behind a clean, idiomatic Elixir interface while maintaining the flexibility needed for production deployments. It transforms raw ExAws operations into predictable, structured responses with unified error handling across all AWS services.

## Key Characteristics

* **Stateless Architecture** - Every operation is self-contained, requiring explicit configuration or relying on centralized defaults from `AWS.Config`.

* **Serverless-Ready** - Designed for ephemeral execution environments with no persistent state requirements.

* **Sandbox-First Development** - Built-in support for local AWS emulators (LocalStack) and inline OTP-based mocking.

* **Standardized Error Handling** - HTTP status codes and network errors are transformed into structured `AWS.Error` responses with consistent formatting.

* **Flexible Configuration** - Per-call overrides for region, credentials, and sandbox settings while maintaining sensible defaults.

## Current Capabilities
The library currently supports:

* **S3 Operations** - Bucket management (create, list) with comprehensive error handling and response serialization.

* **HTTP Abstraction** - Unified HTTP client configuration supporting both production AWS endpoints and sandbox environments.

* **Multipart Uploads** - Complete support for multipart uploads including create, abort, upload, list, and copy operations.

* **Error Management** - Structured error types (conflict, not found, service unavailable, etc.) with detailed context.

* **Response Serialization** - Automatic transformation of AWS responses into standardized data structures.

## Design Philosophy

The architecture prioritizes developer experience by offering sensible defaults while allowing granular control when needed. This makes it equally suitable for rapid prototyping with local emulators and production deployments against live AWS infrastructure. The stateless design ensures compatibility with modern serverless platforms while the sandbox capabilities enable fast, cost-free development iterations.

## Dependencies
 
This application uses the following dependencies:
 
- **ex_aws** - Core AWS client library for Elixir. Provides the foundational infrastructure for making AWS API calls, handling authentication, and managing request/response cycles. Required for all AWS service interactions.
 
- **ex_aws_s3** - S3-specific operations built on top of ExAws. Provides high-level functions for bucket management, object operations, and multipart uploads. Use this for all S3 interactions including bucket creation, object storage, retrieval, and deletion.
 
- **sweet_xml** - XML parsing library used by ExAws to parse XML responses from AWS services. Required dependency for ExAws S3 operations as S3 returns XML-formatted responses.
 
- **timex** - DateTime manipulation library used for generating HTTP date headers and handling expiration times in presigned URLs and multipart uploads. Required for time-based operations like presigned URL generation.
 
- **finch** - HTTP client used by ExAws to make actual HTTP requests to AWS endpoints. Provides connection pooling and efficient HTTP/1.1 and HTTP/2 support for AWS API calls.
 
- **req** - High-level HTTP client that may be used for additional HTTP operations or testing. Provides a more ergonomic interface for HTTP requests compared to lower-level clients.
 
- **error_message** - Error formatting library used to generate structured, human-readable error messages. Used throughout the application to provide consistent error reporting in `AWS.Error`.
 
- **recase** - String case conversion library used to transform AWS response keys (typically PascalCase or kebab-case) into Elixir-friendly snake_case atoms. Essential for response serialization in `AWS.Serializer`.