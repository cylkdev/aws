defmodule Mix.Tasks.AWS.S3.DisableEventBridge do
  @shortdoc "Disables EventBridge notifications on an S3 bucket"

  @moduledoc """
  Disables EventBridge notifications on an S3 bucket.

  Other notification configurations (SNS, SQS, Lambda) are preserved.
  This operation is idempotent.

  ## Usage

      mix aws.s3.disable_event_bridge BUCKET [options]

  ## Options

    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.s3.disable_event_bridge my-bucket
      mix aws.s3.disable_event_bridge my-bucket --region us-east-1
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")
    {parsed, args, _} = Helpers.parse_opts(argv)

    bucket = List.first(args) || Mix.raise("Usage: mix aws.s3.disable_event_bridge BUCKET")
    opts = Helpers.build_opts(parsed)

    bucket
    |> AWS.S3.disable_event_bridge(opts)
    |> Helpers.handle_result()
  end
end
