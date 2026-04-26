defmodule Mix.Tasks.AWS.Eventbridge.ListTargets do
  @shortdoc "Lists targets attached to an EventBridge rule"

  @moduledoc """
  Lists targets attached to an EventBridge rule.

  ## Usage

      mix aws.eventbridge.list_targets RULE [options]

  ## Options

    * `--event-bus-name` — Custom event bus name
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.eventbridge.list_targets my-rule
      mix aws.eventbridge.list_targets my-rule --region us-east-1
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")
    {parsed, args, _} = Helpers.parse_opts(argv)

    rule = List.first(args) || Mix.raise("Usage: mix aws.eventbridge.list_targets RULE")
    opts = Helpers.build_opts(parsed)

    rule
    |> AWS.EventBridge.list_targets_by_rule(opts)
    |> Helpers.handle_result()
  end
end
