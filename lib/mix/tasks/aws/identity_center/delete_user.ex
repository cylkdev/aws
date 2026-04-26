defmodule Mix.Tasks.AWS.IdentityCenter.DeleteUser do
  @shortdoc "Deletes a user from the Identity Center identity store"

  @moduledoc """
  Deletes a user from the IAM Identity Center identity store.

  ## Usage

      mix aws.identity_center.delete_user --identity-store-id ID --user-id ID [options]

  ## Options

    * `--identity-store-id` — Identity store ID (required)
    * `--user-id` — User ID (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.delete_user --identity-store-id d-123456 --user-id abc123-user-id
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} = Helpers.parse_opts(argv, identity_store_id: :string, user_id: :string)

    identity_store_id = parsed[:identity_store_id] || Mix.raise("--identity-store-id is required")
    user_id = parsed[:user_id] || Mix.raise("--user-id is required")

    opts = Helpers.build_opts(parsed)

    identity_store_id
    |> AWS.IdentityCenter.delete_identity_store_user(user_id, opts)
    |> Helpers.handle_result()
  end
end
