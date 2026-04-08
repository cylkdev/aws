defmodule Mix.Tasks.Aws.Iam.AddUserToGroup do
  @shortdoc "Adds an IAM user to a group"

  @moduledoc """
  Adds an IAM user to a group.

  ## Usage

      mix aws.iam.add_user_to_group --group GROUP --user USER [options]

  ## Options

    * `--group` — Group name (required)
    * `--user` — User name (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.add_user_to_group --group engineers --user alice
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, group: :string, user: :string)

    group_name = parsed[:group] || Mix.raise("--group is required")
    username = parsed[:user] || Mix.raise("--user is required")

    opts = Helpers.build_opts(parsed)

    AWS.IAM.add_user_to_group(group_name, username, opts)
    |> Helpers.handle_result()
  end
end
