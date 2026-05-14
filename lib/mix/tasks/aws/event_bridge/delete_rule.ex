defmodule Mix.Tasks.AWS.Eventbridge.DeleteRule do
  @shortdoc "Deletes an EventBridge rule"

  @moduledoc """
  Deletes an EventBridge rule. All targets must be removed before deleting,
  unless `--force` is used (which calls AWS with `Force: true`).

  ## Usage

      mix aws.eventbridge.delete_rule RULE [options]

  ## Options

    * `--event-bus-name` — Custom event bus name
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)
    * `--force` / `-f` — Force deletion even if targets are attached (managed rules only)

  ## Examples

      mix aws.eventbridge.delete_rule my-rule
      mix aws.eventbridge.delete_rule my-rule --force
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

    rule = List.first(args) || Mix.raise("Usage: mix aws.eventbridge.delete_rule RULE")

    opts =
      parsed
      |> Helpers.build_opts()
      |> Helpers.maybe_put(:force, parsed[:force])

    rule
    |> AWS.EventBridge.delete_rule(opts)
    |> Helpers.handle_result()
  end
end
