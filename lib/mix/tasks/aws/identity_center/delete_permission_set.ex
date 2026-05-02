defmodule Mix.Tasks.AWS.IdentityCenter.DeletePermissionSet do
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
  alias Mix.Tasks.AWS.Helpers

  # @requirements declares the Mix tasks that must run before this task.
  #
  # When this task is invoked, Mix runs each requirement once with Mix.Task.run/2
  # before calling this task's run/1 function.
  #
  # This makes task dependencies explicit in the task definition instead of
  # requiring run/1 to start dependencies manually or requiring callers to compose
  # tasks themselves.
  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
    {parsed, _args, _} =
      Helpers.parse_opts(argv, instance_arn: :string, permission_set_arn: :string)

    instance_arn = parsed[:instance_arn] || Mix.raise("--instance-arn is required")

    permission_set_arn =
      parsed[:permission_set_arn] || Mix.raise("--permission-set-arn is required")

    opts = Helpers.build_opts(parsed)

    instance_arn
    |> AWS.IdentityCenter.delete_permission_set(permission_set_arn, opts)
    |> Helpers.handle_result()
  end
end
