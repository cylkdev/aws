defmodule Mix.Tasks.AWS.IAM.ListUsers do
  @shortdoc "Lists IAM users"

  @moduledoc """
  Lists IAM users, optionally filtered by path prefix.

  ## Usage

      mix aws.iam.list_users [options]

  ## Options

    * `--path-prefix` — Filter users whose path begins with this string
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.list_users
      mix aws.iam.list_users --path-prefix /engineering/
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} = Helpers.parse_opts(argv, path_prefix: :string)

    opts =
      parsed
      |> Helpers.build_opts()
      |> Helpers.maybe_put(:path_prefix, parsed[:path_prefix])

    opts
    |> AWS.IAM.list_users()
    |> Helpers.handle_result()
  end
end
