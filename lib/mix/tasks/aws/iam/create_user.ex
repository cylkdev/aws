defmodule Mix.Tasks.AWS.IAM.CreateUser do
  @shortdoc "Creates an IAM user"

  @moduledoc """
  Creates an IAM user. Skips if a user with the same name already exists
  unless `--force` is given.

  ## Usage

      mix aws.iam.create_user --name NAME [options]

  ## Options

    * `--name` — User name (required)
    * `--path` — IAM path for the user (default: `/`)
    * `--force` / `-f` — Proceed even if user already exists
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.create_user --name alice
      mix aws.iam.create_user --name alice --path /engineering/
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} =
      Helpers.parse_opts(argv, name: :string, path: :string)

    username = parsed[:name] || Mix.raise("--name is required")

    opts =
      parsed
      |> Helpers.build_opts()
      |> Helpers.maybe_put(:path, parsed[:path])

    force = parsed[:force] || false

    Helpers.idempotent(
      username,
      fn -> AWS.IAM.get_user(username, opts) end,
      fn ->
        username
        |> AWS.IAM.create_user(opts)
        |> Helpers.handle_result()
      end,
      force
    )
  end
end
