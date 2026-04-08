defmodule Mix.Tasks.Aws.Iam.DeleteRole do
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
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, name: :string)

    name = parsed[:name] || Mix.raise("--name is required")

    opts = Helpers.build_opts(parsed)

    AWS.IAM.delete_role(name, opts)
    |> Helpers.handle_result()
  end
end
