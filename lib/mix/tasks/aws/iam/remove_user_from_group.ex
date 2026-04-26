defmodule Mix.Tasks.AWS.IAM.RemoveUserFromGroup do
  @shortdoc "Removes an IAM user from a group"

  @moduledoc """
  Removes an IAM user from a group.

  ## Usage

      mix aws.iam.remove_user_from_group --group GROUP --user USER [options]

  ## Options

    * `--group` — Group name (required)
    * `--user` — User name (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.remove_user_from_group --group engineers --user alice
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} = Helpers.parse_opts(argv, group: :string, user: :string)

    group_name = parsed[:group] || Mix.raise("--group is required")
    username = parsed[:user] || Mix.raise("--user is required")

    opts = Helpers.build_opts(parsed)

    group_name
    |> AWS.IAM.remove_user_from_group(username, opts)
    |> Helpers.handle_result()
  end
end
