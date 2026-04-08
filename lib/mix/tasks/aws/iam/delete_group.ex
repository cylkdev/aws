defmodule Mix.Tasks.Aws.Iam.DeleteGroup do
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
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, name: :string)

    name = parsed[:name] || Mix.raise("--name is required")

    opts = Helpers.build_opts(parsed)

    AWS.IAM.delete_group(name, opts)
    |> Helpers.handle_result()
  end
end
