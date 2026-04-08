defmodule Mix.Tasks.Aws.IdentityCenter.DeletePermissionSet do
  @shortdoc "Deletes an Identity Center permission set"

  @moduledoc """
  Deletes a permission set from an IAM Identity Center instance.

  ## Usage

      mix aws.identity_center.delete_permission_set --instance-arn ARN --permission-set-arn ARN [options]

  ## Options

    * `--instance-arn` — Identity Center instance ARN (required)
    * `--permission-set-arn` — Permission set ARN (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.delete_permission_set \\
        --instance-arn arn:aws:sso:::instance/ssoins-1 \\
        --permission-set-arn arn:aws:sso:::permissionSet/ssoins-1/ps-123456
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, instance_arn: :string, permission_set_arn: :string)

    instance_arn = parsed[:instance_arn] || Mix.raise("--instance-arn is required")
    permission_set_arn = parsed[:permission_set_arn] || Mix.raise("--permission-set-arn is required")

    opts = Helpers.build_opts(parsed)

    AWS.IdentityCenter.delete_permission_set(instance_arn, permission_set_arn, opts)
    |> Helpers.handle_result()
  end
end
