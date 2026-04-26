defmodule Mix.Tasks.AWS.IAM.DeleteUser do
  @shortdoc "Deletes an IAM user"

  @moduledoc """
  Deletes an IAM user.

  ## Usage

      mix aws.iam.delete_user --name NAME [options]

  ## Options

    * `--name` — User name (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.delete_user --name alice
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} = Helpers.parse_opts(argv, name: :string)

    username = parsed[:name] || Mix.raise("--name is required")
    opts = Helpers.build_opts(parsed)

    username
    |> AWS.IAM.delete_user(opts)
    |> Helpers.handle_result()
  end
end
