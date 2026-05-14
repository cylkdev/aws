defmodule Mix.Tasks.AWS.IAM.DeleteGroup do
  @shortdoc "Deletes an IAM group"

  @moduledoc """
  Deletes an IAM group.

  ## Usage

      mix aws.iam.delete_group --name NAME [options]

  ## Options

    * `--name` — Group name (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.delete_group --name engineers
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
    {parsed, _args, _} = Helpers.parse_opts(argv, name: :string)

    name = parsed[:name] || Mix.raise("--name is required")

    opts = Helpers.build_opts(parsed)

    name
    |> AWS.IAM.delete_group(opts)
    |> Helpers.handle_result()
  end
end
