defmodule Mix.Tasks.Aws.IdentityCenter.DeleteGroup do
  @shortdoc "Deletes a group from the Identity Center identity store"

  @moduledoc """
  Deletes a group from the IAM Identity Center identity store.

  ## Usage

      mix aws.identity_center.delete_group --identity-store-id ID --group-id ID [options]

  ## Options

    * `--identity-store-id` — Identity store ID (required)
    * `--group-id` — Group ID (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.delete_group --identity-store-id d-123456 --group-id abc123-group-id
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, identity_store_id: :string, group_id: :string)

    identity_store_id = parsed[:identity_store_id] || Mix.raise("--identity-store-id is required")
    group_id = parsed[:group_id] || Mix.raise("--group-id is required")

    opts = Helpers.build_opts(parsed)

    AWS.IdentityCenter.delete_identity_store_group(identity_store_id, group_id, opts)
    |> Helpers.handle_result()
  end
end
