defmodule Mix.Tasks.Aws.Iam.DeleteAccessKey do
  @shortdoc "Deletes an IAM access key"

  @moduledoc """
  Deletes an IAM access key for a user.

  ## Usage

      mix aws.iam.delete_access_key --key-id KEY_ID --user USER [options]

  ## Options

    * `--key-id` — Access key ID (required)
    * `--user` — User name (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.delete_access_key --key-id AKIAIOSFODNN7EXAMPLE --user alice
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, key_id: :string, user: :string)

    access_key_id = parsed[:key_id] || Mix.raise("--key-id is required")
    username = parsed[:user] || Mix.raise("--user is required")
    opts = Helpers.build_opts(parsed)

    AWS.IAM.delete_access_key(access_key_id, username, opts)
    |> Helpers.handle_result()
  end
end
