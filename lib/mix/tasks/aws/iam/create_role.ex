defmodule Mix.Tasks.Aws.Iam.CreateRole do
  @shortdoc "Creates an IAM role with a trust policy"

  @moduledoc """
  Creates an IAM role. Skips if a role with the same name already exists
  unless `--force` is given.

  The trust policy defines which principals can assume the role (e.g. Lambda,
  EC2, another AWS account). Pass it as a JSON string via `--trust-policy`.

  ## Usage

      mix aws.iam.create_role --name NAME --trust-policy JSON [options]

  ## Options

    * `--name` — Role name (required)
    * `--trust-policy` — JSON trust policy document (required)
    * `--description` — Role description
    * `--path` — IAM path (default: `/`)
    * `--max-session-duration` — Max session duration in seconds (default: 3600)
    * `--force` / `-f` — Proceed even if role already exists
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.create_role --name MyLambdaRole \\
        --trust-policy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

      mix aws.iam.create_role --name MyEC2Role \\
        --trust-policy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \\
        --description "Role for EC2 instances"
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        name: :string,
        trust_policy: :string,
        description: :string,
        path: :string,
        max_session_duration: :integer
      )

    name = parsed[:name] || Mix.raise("--name is required")

    trust_policy_json =
      parsed[:trust_policy] || Mix.raise("--trust-policy is required")

    trust_policy =
      case Jason.decode(trust_policy_json) do
        {:ok, map} -> map
        {:error, _} -> Mix.raise("--trust-policy is not valid JSON")
      end

    opts =
      Helpers.build_opts(parsed)
      |> Helpers.maybe_put(:description, parsed[:description])
      |> Helpers.maybe_put(:path, parsed[:path])
      |> Helpers.maybe_put(:max_session_duration, parsed[:max_session_duration])

    force = parsed[:force] || false

    Helpers.idempotent(
      name,
      fn -> AWS.IAM.get_role(name, opts) end,
      fn ->
        AWS.IAM.create_role(name, trust_policy, opts)
        |> Helpers.handle_result()
      end,
      force
    )
  end
end
