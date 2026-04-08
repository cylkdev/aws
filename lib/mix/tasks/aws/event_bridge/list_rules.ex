defmodule Mix.Tasks.Aws.Eventbridge.ListRules do
  @shortdoc "Lists EventBridge rules"

  @moduledoc """
  Lists EventBridge rules, optionally filtered by name prefix.

  ## Usage

      mix aws.eventbridge.list_rules [options]

  ## Options

    * `--name-prefix` — Filter rules whose names begin with this string
    * `--event-bus-name` — Custom event bus name
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.eventbridge.list_rules
      mix aws.eventbridge.list_rules --name-prefix my-s3
      mix aws.eventbridge.list_rules --event-bus-name my-bus
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)
    {parsed, _args, _} = Helpers.parse_opts(argv, name_prefix: :string)

    opts =
      Helpers.build_opts(parsed)
      |> Helpers.maybe_put(:name_prefix, parsed[:name_prefix])

    AWS.EventBridge.list_rules(opts)
    |> Helpers.handle_result()
  end
end
