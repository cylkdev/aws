defmodule Mix.Tasks.AWS.IdentityCenter.ListUsers do
  @shortdoc "Lists users in the Identity Center identity store"

  @moduledoc """
  Lists users in the IAM Identity Center identity store.

  ## Usage

      mix aws.identity_center.list_users --identity-store-id ID [options]

  ## Options

    * `--identity-store-id` — Identity store ID (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.list_users --identity-store-id d-123456
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} = Helpers.parse_opts(argv, identity_store_id: :string)

    identity_store_id = parsed[:identity_store_id] || Mix.raise("--identity-store-id is required")

    opts = Helpers.build_opts(parsed)

    identity_store_id
    |> AWS.IdentityCenter.list_identity_store_users(opts)
    |> Helpers.handle_result()
  end
end
