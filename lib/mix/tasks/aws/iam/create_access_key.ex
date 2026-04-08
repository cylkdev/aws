defmodule Mix.Tasks.Aws.Iam.CreateAccessKey do
  @shortdoc "Creates an IAM access key for a user"

  @moduledoc """
  Creates an access key pair for an IAM user. The secret access key is only
  visible at creation time — save it immediately.

  ## Usage

      mix aws.iam.create_access_key --user USER [options]

  ## Options

    * `--user` — User name (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.create_access_key --user alice
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, user: :string)

    username = parsed[:user] || Mix.raise("--user is required")
    opts = Helpers.build_opts(parsed)

    AWS.IAM.create_access_key(username, opts)
    |> Helpers.handle_result()
  end
end
