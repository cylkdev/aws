defmodule Mix.Tasks.AWS.S3.GetNotificationConfig do
  @shortdoc "Shows the notification configuration for an S3 bucket"

  @moduledoc """
  Shows the notification configuration for an S3 bucket, including whether
  EventBridge notifications are enabled.

  ## Usage

      mix aws.s3.get_notification_config BUCKET [options]

  ## Options

    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.s3.get_notification_config my-bucket
      mix aws.s3.get_notification_config my-bucket --region us-east-1
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  # @requirements declares the Mix tasks that must run before this task.
  #
  # When this task is invoked, Mix runs each requirement once with Mix.Task.run/2
  # before calling this task's run/1 function.
  #
  # This makes task dependencies explicit in the task definition instead of
  # requiring run/1 to start dependencies manually or requiring callers to compose
  # tasks themselves.
  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
    {parsed, args, _} = Helpers.parse_opts(argv)

    bucket = List.first(args) || Mix.raise("Usage: mix aws.s3.get_notification_config BUCKET")
    opts = Helpers.build_opts(parsed)

    bucket
    |> AWS.S3.get_notification_configuration(opts)
    |> Helpers.handle_result()
  end
end
