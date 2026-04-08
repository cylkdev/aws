defmodule Mix.Tasks.Aws.Iam.DeletePolicy do
  @shortdoc "Deletes a managed IAM policy"

  @moduledoc """
  Deletes a managed IAM policy by ARN.

  Note: All policy attachments must be removed before the policy can be deleted.

  ## Usage

      mix aws.iam.delete_policy --arn ARN [options]

  ## Options

    * `--arn` — Policy ARN (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.delete_policy --arn arn:aws:iam::123456789012:policy/MyS3ReadPolicy
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, arn: :string)

    policy_arn = parsed[:arn] || Mix.raise("--arn is required")

    opts = Helpers.build_opts(parsed)

    AWS.IAM.delete_policy(policy_arn, opts)
    |> Helpers.handle_result()
  end
end
