defmodule Mix.Tasks.Aws.S3.TeardownEvents do
  @shortdoc "Removes S3 EventBridge event routing for a bucket"

  @moduledoc """
  Tears down S3 EventBridge event routing for a bucket in order:

    1. Removes the target from the rule
    2. Deletes the rule
    3. Disables EventBridge notifications on the bucket

  Each step is idempotent — missing resources are treated as already removed.

  ## Usage

      mix aws.s3.teardown_events BUCKET RULE TARGET_ID [options]

  ## Arguments

    * `BUCKET` — S3 bucket name
    * `RULE` — EventBridge rule name
    * `TARGET_ID` — Target ID to remove from the rule

  ## Options

    * `--event-bus-name` — Custom event bus name (default: AWS default bus)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.s3.teardown_events my-bucket my-rule my-queue
      mix aws.s3.teardown_events my-bucket my-rule my-queue --region us-east-1
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)
    {parsed, args, _} = Helpers.parse_opts(argv)

    [bucket, rule, target_id] =
      case args do
        [b, r, ti | _] -> [b, r, ti]
        _ -> Mix.raise("Usage: mix aws.s3.teardown_events BUCKET RULE TARGET_ID")
      end

    opts = Helpers.build_opts(parsed)

    Mix.shell().info("Step 1/3: Removing target '#{target_id}' from rule '#{rule}'...")

    case AWS.EventBridge.remove_targets(rule, [target_id], opts) do
      {:ok, _} -> Mix.shell().info("OK")
      {:error, %{code: :not_found}} -> Mix.shell().info("Target not found, skipping")
      {:error, error} -> Mix.raise("AWS error: #{inspect(error)}")
    end

    Mix.shell().info("Step 2/3: Deleting rule '#{rule}'...")

    case AWS.EventBridge.delete_rule(rule, opts) do
      {:ok, _} -> Mix.shell().info("OK")
      {:error, %{code: :not_found}} -> Mix.shell().info("Rule not found, skipping")
      {:error, error} -> Mix.raise("AWS error: #{inspect(error)}")
    end

    Mix.shell().info("Step 3/3: Disabling EventBridge on bucket '#{bucket}'...")

    AWS.S3.disable_event_bridge(bucket, opts)
    |> Helpers.handle_result()

    Mix.shell().info("Done.")
  end
end
