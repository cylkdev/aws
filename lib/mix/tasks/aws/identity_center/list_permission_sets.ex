defmodule Mix.Tasks.Aws.IdentityCenter.ListPermissionSets do
  @shortdoc "Lists permission sets in an Identity Center instance"

  @moduledoc """
  Lists permission set ARNs in an IAM Identity Center instance.

  ## Usage

      mix aws.identity_center.list_permission_sets --instance-arn ARN [options]

  ## Options

    * `--instance-arn` — Identity Center instance ARN (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.list_permission_sets --instance-arn arn:aws:sso:::instance/ssoins-1
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} = Helpers.parse_opts(argv, instance_arn: :string)

    instance_arn = parsed[:instance_arn] || Mix.raise("--instance-arn is required")

    opts = Helpers.build_opts(parsed)

    AWS.IdentityCenter.list_permission_sets(instance_arn, opts)
    |> Helpers.handle_result()
  end
end
