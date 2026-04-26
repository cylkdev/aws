defmodule Mix.Tasks.AWS.Eventbridge.DeleteConnection do
  @shortdoc "Deletes an EventBridge connection"

  @moduledoc """
  Deletes an EventBridge connection.

  ## Usage

      mix aws.eventbridge.delete_connection NAME [options]

  ## Options

    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.eventbridge.delete_connection my-conn
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")
    {parsed, args, _} = Helpers.parse_opts(argv)

    name = List.first(args) || Mix.raise("Usage: mix aws.eventbridge.delete_connection NAME")
    opts = Helpers.build_opts(parsed)

    name
    |> AWS.EventBridge.delete_connection(opts)
    |> Helpers.handle_result()
  end
end
