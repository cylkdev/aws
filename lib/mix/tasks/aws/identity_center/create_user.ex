defmodule Mix.Tasks.Aws.IdentityCenter.CreateUser do
  @shortdoc "Creates a user in the Identity Center identity store"

  @moduledoc """
  Creates a user in the IAM Identity Center identity store.

  ## Usage

      mix aws.identity_center.create_user --identity-store-id ID --username NAME [options]

  ## Options

    * `--identity-store-id` — Identity store ID (required)
    * `--username` — User name (required)
    * `--display-name` — Full display name for the user
    * `--given-name` — First name
    * `--family-name` — Last name
    * `--email` — Primary email address
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.create_user --identity-store-id d-123456 --username alice --display-name "Alice Smith" --email alice@example.com
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        identity_store_id: :string,
        username: :string,
        display_name: :string,
        given_name: :string,
        family_name: :string,
        email: :string
      )

    identity_store_id = parsed[:identity_store_id] || Mix.raise("--identity-store-id is required")
    username = parsed[:username] || Mix.raise("--username is required")

    opts =
      Helpers.build_opts(parsed)
      |> Helpers.maybe_put(:display_name, parsed[:display_name])
      |> Helpers.maybe_put(:given_name, parsed[:given_name])
      |> Helpers.maybe_put(:family_name, parsed[:family_name])
      |> then(fn o ->
        case parsed[:email] do
          nil -> o
          email -> Keyword.put(o, :emails, [%{"Value" => email, "Type" => "work", "Primary" => true}])
        end
      end)

    AWS.IdentityCenter.create_identity_store_user(identity_store_id, username, opts)
    |> Helpers.handle_result()
  end
end
