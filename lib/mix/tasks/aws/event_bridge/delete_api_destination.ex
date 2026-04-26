defmodule Mix.Tasks.AWS.Eventbridge.DeleteApiDestination do
  @shortdoc "Deletes an EventBridge API destination"

  @moduledoc """
  Deletes an EventBridge API destination.

  ## Usage

      mix aws.eventbridge.delete_api_destination NAME [options]

  ## Options

    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.eventbridge.delete_api_destination my-dest
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")
    {parsed, args, _} = Helpers.parse_opts(argv)

    name = List.first(args) || Mix.raise("Usage: mix aws.eventbridge.delete_api_destination NAME")
    opts = Helpers.build_opts(parsed)

    name
    |> AWS.EventBridge.delete_api_destination(opts)
    |> Helpers.handle_result()
  end
end
