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

  # @requirements declares the Mix tasks that must run before this task.
  #
  # When this task is invoked, Mix runs each requirement once with Mix.Task.run/2
  # before calling this task's run/1 function.
  #
  # This makes task dependencies explicit in the task definition instead of
  # requiring run/1 to start dependencies manually or requiring callers to compose
  # tasks themselves.
  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
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
