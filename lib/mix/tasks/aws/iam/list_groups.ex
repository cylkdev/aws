defmodule Mix.Tasks.Aws.Iam.ListGroups do
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
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, path_prefix: :string)

    opts =
      Helpers.build_opts(parsed)
      |> Helpers.maybe_put(:path_prefix, parsed[:path_prefix])

    AWS.IAM.list_groups(opts)
    |> Helpers.handle_result()
  end
end
