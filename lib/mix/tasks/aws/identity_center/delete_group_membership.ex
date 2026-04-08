defmodule Mix.Tasks.Aws.IdentityCenter.DeleteGroupMembership do
  @shortdoc "Removes a user from an Identity Center group"

  @moduledoc """
  Removes a user from a group in the IAM Identity Center identity store by
  membership ID (obtained from `create_group_membership`).

  ## Usage

      mix aws.identity_center.delete_group_membership --identity-store-id ID --membership-id ID [options]

  ## Options

    * `--identity-store-id` — Identity store ID (required)
    * `--membership-id` — Membership ID (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.delete_group_membership --identity-store-id d-123456 --membership-id membership-abc123
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} =
      Helpers.parse_opts(argv, identity_store_id: :string, membership_id: :string)

    identity_store_id = parsed[:identity_store_id] || Mix.raise("--identity-store-id is required")
    membership_id = parsed[:membership_id] || Mix.raise("--membership-id is required")

    opts = Helpers.build_opts(parsed)

    AWS.IdentityCenter.delete_group_membership(identity_store_id, membership_id, opts)
    |> Helpers.handle_result()
  end
end
