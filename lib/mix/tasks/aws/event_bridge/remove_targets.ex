defmodule Mix.Tasks.AWS.Eventbridge.RemoveTargets do
  @shortdoc "Removes targets from an EventBridge rule"

  @moduledoc """
  Removes one or more targets from an EventBridge rule.

  ## Usage

      mix aws.eventbridge.remove_targets RULE TARGET_ID [TARGET_ID ...] [options]

  ## Options

    * `--event-bus-name` — Custom event bus name
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.eventbridge.remove_targets my-rule my-queue
      mix aws.eventbridge.remove_targets my-rule my-queue my-lambda
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

    case args do
      [rule | [_ | _] = target_ids] ->
        opts = Helpers.build_opts(parsed)

        rule
        |> AWS.EventBridge.remove_targets(target_ids, opts)
        |> Helpers.handle_result()

      _ ->
        Mix.raise("Usage: mix aws.eventbridge.remove_targets RULE TARGET_ID [TARGET_ID ...]")
    end
  end
end
