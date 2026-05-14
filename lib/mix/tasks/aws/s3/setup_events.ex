defmodule Mix.Tasks.AWS.S3.SetupEvents do
  @shortdoc "Sets up S3 EventBridge event routing for a bucket"

  @moduledoc """
  Sets up S3 EventBridge event routing for a bucket in one step:

    1. Enables EventBridge notifications on the bucket
    2. Creates an EventBridge rule matching S3 events
    3. Attaches the given target to the rule

  Each step is idempotent by default — existing resources are skipped.
  Use `--force` to update them.

  ## Usage

      mix aws.s3.setup_events BUCKET RULE TARGET_ID TARGET_ARN [options]

  ## Arguments

    * `BUCKET` — S3 bucket name
    * `RULE` — EventBridge rule name to create
    * `TARGET_ID` — Unique identifier for the target (e.g. `"my-queue"`)
    * `TARGET_ARN` — ARN of the target resource (SQS, Lambda, API destination, etc.)

  ## Options

    * `--event-type` — One of `created`, `deleted`, or `all` (default: `all`)
    * `--state` — Rule state: `ENABLED` or `DISABLED` (default: `ENABLED`)
    * `--event-bus-name` — Custom event bus name (default: AWS default bus)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)
    * `--force` / `-f` — Update existing resources instead of skipping them

  ## Examples

      mix aws.s3.setup_events my-bucket my-rule my-queue arn:aws:sqs:us-east-1:123:my-queue
      mix aws.s3.setup_events my-bucket my-rule my-fn arn:aws:lambda:us-east-1:123:function:fn --event-type created
      mix aws.s3.setup_events my-bucket my-rule my-queue arn:aws:sqs:... --force
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
    {parsed, args, _} =
      Helpers.parse_opts(argv, event_type: :string, state: :string)

    [bucket, rule, target_id, target_arn] =
      case args do
        [b, r, ti, ta | _] -> [b, r, ti, ta]
        _ -> Mix.raise("Usage: mix aws.s3.setup_events BUCKET RULE TARGET_ID TARGET_ARN")
      end

    opts = Helpers.build_opts(parsed)
    force = parsed[:force] || false
    event_pattern = build_event_pattern(parsed[:event_type] || "all", bucket)
    state = parsed[:state] || "ENABLED"

    Mix.shell().info("Step 1/3: Enabling EventBridge on bucket '#{bucket}'...")

    bucket
    |> AWS.S3.enable_event_bridge(opts)
    |> Helpers.handle_result()

    Mix.shell().info("Step 2/3: Creating rule '#{rule}'...")

    result =
      Helpers.idempotent(
        rule,
        fn -> AWS.EventBridge.describe_rule(rule, opts) end,
        fn ->
          Helpers.handle_result(
            AWS.EventBridge.put_rule(
              rule,
              Keyword.merge(opts, event_pattern: event_pattern, state: state)
            )
          )
        end,
        force
      )

    if match?({:error, _}, result), do: Helpers.handle_result(result)

    Mix.shell().info("Step 3/3: Attaching target '#{target_id}'...")

    result =
      Helpers.idempotent(
        target_id,
        fn -> Helpers.find_target(rule, target_id, opts) end,
        fn ->
          Helpers.handle_result(
            AWS.EventBridge.put_targets(rule, [%{id: target_id, arn: target_arn}], opts)
          )
        end,
        force
      )

    if match?({:error, _}, result), do: Helpers.handle_result(result)

    Mix.shell().info("Done.")
  end

  defp build_event_pattern("created", bucket),
    do: AWS.EventBridge.s3_object_created_pattern(bucket)

  defp build_event_pattern("deleted", bucket),
    do: AWS.EventBridge.s3_object_deleted_pattern(bucket)

  defp build_event_pattern(_, bucket), do: AWS.EventBridge.s3_all_events_pattern(bucket)
end
