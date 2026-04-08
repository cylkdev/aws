defmodule Mix.Tasks.Aws.Iam.CreatePolicy do
  @shortdoc "Creates a managed IAM policy"

  @moduledoc """
  Creates a managed IAM policy. Skips if a policy with the same name already
  exists unless `--force` is given.

  ## Usage

      mix aws.iam.create_policy --name NAME --policy-document JSON [options]

  ## Options

    * `--name` — Policy name (required)
    * `--policy-document` — JSON policy document (required)
    * `--description` — Policy description
    * `--path` — IAM path (default: `/`)
    * `--force` / `-f` — Proceed even if a policy with this name already exists
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.create_policy --name MyS3ReadPolicy \\
        --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject"],"Resource":"arn:aws:s3:::my-bucket/*"}]}'
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        name: :string,
        policy_document: :string,
        description: :string,
        path: :string
      )

    name = parsed[:name] || Mix.raise("--name is required")

    policy_json =
      parsed[:policy_document] || Mix.raise("--policy-document is required")

    policy_document =
      case Jason.decode(policy_json) do
        {:ok, map} -> map
        {:error, _} -> Mix.raise("--policy-document is not valid JSON")
      end

    opts =
      Helpers.build_opts(parsed)
      |> Helpers.maybe_put(:description, parsed[:description])
      |> Helpers.maybe_put(:path, parsed[:path])

    force = parsed[:force] || false

    Helpers.idempotent(
      name,
      fn ->
        case AWS.IAM.list_policies(Keyword.merge(opts, scope: "Local")) do
          {:ok, %{policies: policies}} ->
            if Enum.any?(policies, &(&1[:policy_name] == name)),
              do: {:ok, %{}},
              else: {:error, %{code: :not_found}}
          error -> error
        end
      end,
      fn ->
        AWS.IAM.create_policy(name, policy_document, opts)
        |> Helpers.handle_result()
      end,
      force
    )
  end
end
