defmodule Mix.Tasks.Aws.IdentityCenter.DeleteAccountAssignment do
  @shortdoc "Removes an account assignment from Identity Center"

  @moduledoc """
  Removes an account assignment (revokes a principal's access to an AWS account).

  ## Usage

      mix aws.identity_center.delete_account_assignment --instance-arn ARN [options]

  ## Options

    * `--instance-arn` — Identity Center instance ARN (required)
    * `--account-id` — AWS account ID (required)
    * `--permission-set-arn` — ARN of the permission set (required)
    * `--principal-type` — `USER` or `GROUP` (required)
    * `--principal-id` — User or group ID (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.delete_account_assignment \\
        --instance-arn arn:aws:sso:::instance/ssoins-1 \\
        --account-id 123456789012 \\
        --permission-set-arn arn:aws:sso:::permissionSet/ssoins-1/ps-123 \\
        --principal-type USER \\
        --principal-id abc123-user-id
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        instance_arn: :string,
        account_id: :string,
        permission_set_arn: :string,
        principal_type: :string,
        principal_id: :string
      )

    instance_arn = parsed[:instance_arn] || Mix.raise("--instance-arn is required")

    account_id = parsed[:account_id] || Mix.raise("--account-id is required")
    permission_set_arn = parsed[:permission_set_arn] || Mix.raise("--permission-set-arn is required")
    principal_type = parsed[:principal_type] || Mix.raise("--principal-type is required")
    principal_id = parsed[:principal_id] || Mix.raise("--principal-id is required")

    opts = Helpers.build_opts(parsed)

    assignment = %{
      target_id: account_id,
      target_type: "AWS_ACCOUNT",
      permission_set_arn: permission_set_arn,
      principal_type: principal_type,
      principal_id: principal_id
    }

    AWS.IdentityCenter.delete_account_assignment(instance_arn, assignment, opts)
    |> Helpers.handle_result()
  end
end
