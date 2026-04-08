defmodule Mix.Tasks.Aws.S3.EnableEventBridge do
  @shortdoc "Enables EventBridge notifications on an S3 bucket"

  @moduledoc """
  Enables EventBridge notifications on an S3 bucket.

  Once enabled, all S3 event types are forwarded to EventBridge. Filtering by
  event type is done at the rule level. This operation is idempotent.

  ## Usage

      mix aws.s3.enable_event_bridge BUCKET [options]

  ## Options

    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.s3.enable_event_bridge my-bucket
      mix aws.s3.enable_event_bridge my-bucket --region us-east-1
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)
    {parsed, args, _} = Helpers.parse_opts(argv)

    bucket = List.first(args) || Mix.raise("Usage: mix aws.s3.enable_event_bridge BUCKET")
    opts = Helpers.build_opts(parsed)

    AWS.S3.enable_event_bridge(bucket, opts)
    |> Helpers.handle_result()
  end
end
