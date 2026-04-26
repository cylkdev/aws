defmodule Mix.Tasks.AWS.IAM.ListGroups do
  @shortdoc "Lists IAM groups"

  @moduledoc """
  Lists IAM groups, optionally filtered by path prefix.

  ## Usage

      mix aws.iam.list_groups [options]

  ## Options

    * `--path-prefix` — Filter groups whose path begins with this string
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.list_groups
      mix aws.iam.list_groups --path-prefix /teams/
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
    |> AWS.IAM.list_groups()
    |> Helpers.handle_result()
  end
end
