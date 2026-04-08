defmodule Mix.Tasks.Aws.IdentityCenter.CreateGroupMembership do
  @shortdoc "Adds a user to an Identity Center group"

  @moduledoc """
  Adds a user to a group in the IAM Identity Center identity store.

  ## Usage

      mix aws.identity_center.create_group_membership --identity-store-id ID --group-id ID --user-id ID [options]

  ## Options

    * `--identity-store-id` — Identity store ID (required)
    * `--group-id` — Group ID (required)
    * `--user-id` — User ID (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.create_group_membership --identity-store-id d-123456 --group-id group-abc --user-id user-xyz
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} =
      Helpers.parse_opts(argv, identity_store_id: :string, group_id: :string, user_id: :string)

    identity_store_id = parsed[:identity_store_id] || Mix.raise("--identity-store-id is required")
    group_id = parsed[:group_id] || Mix.raise("--group-id is required")
    user_id = parsed[:user_id] || Mix.raise("--user-id is required")

    opts = Helpers.build_opts(parsed)

    AWS.IdentityCenter.create_group_membership(identity_store_id, group_id, user_id, opts)
    |> Helpers.handle_result()
  end
end
