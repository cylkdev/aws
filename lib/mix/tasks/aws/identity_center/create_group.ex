defmodule Mix.Tasks.Aws.IdentityCenter.CreateGroup do
  @shortdoc "Creates a group in the Identity Center identity store"

  @moduledoc """
  Creates a group in the IAM Identity Center identity store.

  ## Usage

      mix aws.identity_center.create_group --identity-store-id ID --name NAME [options]

  ## Options

    * `--identity-store-id` — Identity store ID (required)
    * `--name` — Group display name (required)
    * `--description` — Group description
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.create_group --identity-store-id d-123456 --name "Engineering Team" --description "All engineers"
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, identity_store_id: :string, name: :string, description: :string)

    identity_store_id = parsed[:identity_store_id] || Mix.raise("--identity-store-id is required")
    display_name = parsed[:name] || Mix.raise("--name is required")

    opts =
      Helpers.build_opts(parsed)
      |> Helpers.maybe_put(:description, parsed[:description])

    AWS.IdentityCenter.create_identity_store_group(identity_store_id, display_name, opts)
    |> Helpers.handle_result()
  end
end
