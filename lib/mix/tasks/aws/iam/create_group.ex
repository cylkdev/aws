defmodule Mix.Tasks.Aws.Iam.CreateGroup do
  @shortdoc "Creates an IAM group"

  @moduledoc """
  Creates an IAM group. Skips if a group with the same name already exists
  unless `--force` is given.

  ## Usage

      mix aws.iam.create_group --name NAME [options]

  ## Options

    * `--name` — Group name (required)
    * `--path` — IAM path for the group (default: `/`)
    * `--force` / `-f` — Proceed even if group already exists
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.create_group --name engineers
      mix aws.iam.create_group --name engineers --path /teams/
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, name: :string, path: :string)

    name = parsed[:name] || Mix.raise("--name is required")

    opts =
      Helpers.build_opts(parsed)
      |> Helpers.maybe_put(:path, parsed[:path])

    force = parsed[:force] || false

    Helpers.idempotent(
      name,
      fn -> AWS.IAM.list_groups(opts) |> find_group(name) end,
      fn ->
        AWS.IAM.create_group(name, opts)
        |> Helpers.handle_result()
      end,
      force
    )
  end

  defp find_group({:ok, %{groups: groups}}, name) do
    if Enum.any?(groups, &(&1[:group_name] == name)) do
      {:ok, %{}}
    else
      {:error, %{code: :not_found}}
    end
  end

  defp find_group({:error, _} = error, _), do: error
end
