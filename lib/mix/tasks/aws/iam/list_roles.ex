defmodule Mix.Tasks.AWS.IAM.ListRoles do
  @shortdoc "Lists IAM roles"

  @moduledoc """
  Lists IAM roles, optionally filtered by path prefix.

  ## Usage

      mix aws.iam.list_roles [options]

  ## Options

    * `--path-prefix` — Filter roles whose path begins with this string
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.list_roles
      mix aws.iam.list_roles --path-prefix /service-roles/
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
    |> AWS.IAM.list_roles()
    |> Helpers.handle_result()
  end
end
