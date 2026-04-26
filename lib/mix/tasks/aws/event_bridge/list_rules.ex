defmodule Mix.Tasks.AWS.Eventbridge.ListRules do
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
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")
    {parsed, _args, _} = Helpers.parse_opts(argv, name_prefix: :string)

    opts =
      parsed
      |> Helpers.build_opts()
      |> Helpers.maybe_put(:name_prefix, parsed[:name_prefix])

    opts
    |> AWS.EventBridge.list_rules()
    |> Helpers.handle_result()
  end
end
