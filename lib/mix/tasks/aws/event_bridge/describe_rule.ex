defmodule Mix.Tasks.Aws.Eventbridge.DescribeRule do
  @shortdoc "Shows details about an EventBridge rule"

  @moduledoc """
  Returns details about an EventBridge rule.

  ## Usage

      mix aws.eventbridge.describe_rule RULE [options]

  ## Options

    * `--event-bus-name` — Custom event bus name
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.eventbridge.describe_rule my-rule
      mix aws.eventbridge.describe_rule my-rule --region us-east-1
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)
    {parsed, args, _} = Helpers.parse_opts(argv)

    rule = List.first(args) || Mix.raise("Usage: mix aws.eventbridge.describe_rule RULE")
    opts = Helpers.build_opts(parsed)

    AWS.EventBridge.describe_rule(rule, opts)
    |> Helpers.handle_result()
  end
end
