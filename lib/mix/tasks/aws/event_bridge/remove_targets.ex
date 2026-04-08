defmodule Mix.Tasks.Aws.Eventbridge.RemoveTargets do
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
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)
    {parsed, args, _} = Helpers.parse_opts(argv)

    case args do
      [rule | [_ | _] = target_ids] ->
        opts = Helpers.build_opts(parsed)

        AWS.EventBridge.remove_targets(rule, target_ids, opts)
        |> Helpers.handle_result()

      _ ->
        Mix.raise("Usage: mix aws.eventbridge.remove_targets RULE TARGET_ID [TARGET_ID ...]")
    end
  end
end
