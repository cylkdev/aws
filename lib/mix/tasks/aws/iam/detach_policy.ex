defmodule Mix.Tasks.AWS.IAM.DetachPolicy do
  @shortdoc "Detaches a managed policy from a role, user, or group"

  @moduledoc """
  Detaches a managed IAM policy from a role, user, or group.
  Exactly one of `--from-role`, `--from-user`, or `--from-group` is required.

  ## Usage

      mix aws.iam.detach_policy --policy-arn ARN --from-role ROLE_NAME [options]
      mix aws.iam.detach_policy --policy-arn ARN --from-user USERNAME [options]
      mix aws.iam.detach_policy --policy-arn ARN --from-group GROUP_NAME [options]

  ## Options

    * `--policy-arn` — Policy ARN to detach (required)
    * `--from-role` — Role name to detach the policy from
    * `--from-user` — User name to detach the policy from
    * `--from-group` — Group name to detach the policy from
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.detach_policy --policy-arn arn:aws:iam::aws:policy/AWSLambdaBasicExecutionRole --from-role MyLambdaRole
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        policy_arn: :string,
        from_role: :string,
        from_user: :string,
        from_group: :string
      )

    policy_arn = parsed[:policy_arn] || Mix.raise("--policy-arn is required")

    opts = Helpers.build_opts(parsed)

    case {parsed[:from_role], parsed[:from_user], parsed[:from_group]} do
      {role, nil, nil} when is_binary(role) ->
        role
        |> AWS.IAM.detach_role_policy(policy_arn, opts)
        |> Helpers.handle_result()

      {nil, user, nil} when is_binary(user) ->
        user
        |> AWS.IAM.detach_user_policy(policy_arn, opts)
        |> Helpers.handle_result()

      {nil, nil, group} when is_binary(group) ->
        group
        |> AWS.IAM.detach_group_policy(policy_arn, opts)
        |> Helpers.handle_result()

      _ ->
        Mix.raise("Exactly one of --from-role, --from-user, or --from-group is required")
    end
  end
end
