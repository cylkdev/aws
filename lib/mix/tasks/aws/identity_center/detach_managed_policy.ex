defmodule Mix.Tasks.AWS.IdentityCenter.DetachManagedPolicy do
  @shortdoc "Detaches a managed policy from a permission set"

  @moduledoc """
  Detaches an AWS managed policy from an Identity Center permission set.

  ## Usage

      mix aws.identity_center.detach_managed_policy --instance-arn ARN --permission-set-arn ARN --policy-arn ARN [options]

  ## Options

    * `--instance-arn` — Identity Center instance ARN (required)
    * `--permission-set-arn` — Permission set ARN (required)
    * `--policy-arn` — Managed policy ARN to detach (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.detach_managed_policy \\
        --instance-arn arn:aws:sso:::instance/ssoins-1 \\
        --permission-set-arn arn:aws:sso:::permissionSet/ssoins-1/ps-123 \\
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        instance_arn: :string,
        permission_set_arn: :string,
        policy_arn: :string
      )

    instance_arn = parsed[:instance_arn] || Mix.raise("--instance-arn is required")

    permission_set_arn =
      parsed[:permission_set_arn] || Mix.raise("--permission-set-arn is required")

    managed_policy_arn = parsed[:policy_arn] || Mix.raise("--policy-arn is required")

    opts = Helpers.build_opts(parsed)

    instance_arn
    |> AWS.IdentityCenter.detach_managed_policy_from_permission_set(
      permission_set_arn,
      managed_policy_arn,
      opts
    )
    |> Helpers.handle_result()
  end
end
