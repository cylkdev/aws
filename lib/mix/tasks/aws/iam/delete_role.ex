defmodule Mix.Tasks.AWS.IAM.DeleteRole do
  @shortdoc "Deletes an IAM role"

  @moduledoc """
  Deletes an IAM role.

  Note: All policies must be detached from the role before it can be deleted.

  ## Usage

      mix aws.iam.delete_role --name NAME [options]

  ## Options

    * `--name` — Role name (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.delete_role --name MyLambdaRole
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} = Helpers.parse_opts(argv, name: :string)

    name = parsed[:name] || Mix.raise("--name is required")

    opts = Helpers.build_opts(parsed)

    name
    |> AWS.IAM.delete_role(opts)
    |> Helpers.handle_result()
  end
end
