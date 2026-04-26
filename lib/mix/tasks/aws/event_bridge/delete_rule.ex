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

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")
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
