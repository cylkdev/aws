defmodule Mix.Tasks.Aws.Iam.ListAccessKeys do
  @shortdoc "Lists access keys for an IAM user"

  @moduledoc """
  Lists access key metadata for an IAM user.

  Note: The `secret_access_key` is not returned by this operation.

  ## Usage

      mix aws.iam.list_access_keys --user USER [options]

  ## Options

    * `--user` — User name (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.list_access_keys --user alice
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, user: :string)

    username = parsed[:user] || Mix.raise("--user is required")
    opts = Helpers.build_opts(parsed)

    AWS.IAM.list_access_keys(username, opts)
    |> Helpers.handle_result()
  end
end
