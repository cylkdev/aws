defmodule Mix.Tasks.Aws.Iam.ListUsers do
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
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, path_prefix: :string)

    opts =
      Helpers.build_opts(parsed)
      |> Helpers.maybe_put(:path_prefix, parsed[:path_prefix])

    AWS.IAM.list_users(opts)
    |> Helpers.handle_result()
  end
end
