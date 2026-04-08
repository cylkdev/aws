defmodule Mix.Tasks.Aws.Iam.SetupUser do
  @shortdoc "Creates a user, generates an access key, and adds them to groups"

  @moduledoc """
  High-level task that creates an IAM user, generates an access key, and
  optionally adds the user to one or more groups. Each step is idempotent.

  The generated `secret_access_key` is printed once — save it immediately.

  ## Usage

      mix aws.iam.setup_user --name NAME [options]

  ## Options

    * `--name` — User name (required)
    * `--groups` — Comma-separated list of groups to add the user to
    * `--path` — IAM path for the user
    * `--force` / `-f` — Proceed even if the user already exists
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.setup_user --name alice
      mix aws.iam.setup_user --name alice --groups engineers,admins
      mix aws.iam.setup_user --name alice --groups developers --path /engineering/
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        name: :string,
        groups: :string,
        path: :string
      )

    username = parsed[:name] || Mix.raise("--name is required")

    opts =
      Helpers.build_opts(parsed)
      |> Helpers.maybe_put(:path, parsed[:path])

    force = parsed[:force] || false
    groups = parse_groups(parsed[:groups])

    # Step 1: Create user
    Mix.shell().info("Step 1/#{2 + length(groups)}: Creating user '#{username}'...")
    user_result = Helpers.idempotent(
      username,
      fn -> AWS.IAM.get_user(username, opts) end,
      fn -> AWS.IAM.create_user(username, opts) end,
      force
    )
    if match?({:error, _}, user_result), do: Helpers.handle_result(user_result)

    # Step 2: Create access key
    step = 2
    Mix.shell().info("Step #{step}/#{2 + length(groups)}: Creating access key...")

    case AWS.IAM.create_access_key(username, opts) do
      {:ok, key} ->
        Mix.shell().info("""
        Access key created:
          Access Key ID:     #{key[:access_key_id]}
          Secret Access Key: #{key[:secret_access_key]}

        Save the secret access key now — it will not be shown again.
        """)
      {:error, _} = error ->
        Helpers.handle_result(error)
    end

    # Step 3+: Add to groups
    groups
    |> Enum.with_index(step + 1)
    |> Enum.each(fn {group, i} ->
      Mix.shell().info("Step #{i}/#{2 + length(groups)}: Adding '#{username}' to group '#{group}'...")
      result = AWS.IAM.add_user_to_group(group, username, opts)
      if match?({:error, _}, result), do: Helpers.handle_result(result)
    end)

    Mix.shell().info("Done. User '#{username}' is ready.")
  end

  defp parse_groups(nil), do: []
  defp parse_groups(""), do: []
  defp parse_groups(groups), do: groups |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
end
