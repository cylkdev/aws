defmodule Mix.Tasks.Aws.Iam.AttachPolicy do
  @shortdoc "Attaches a managed policy to a role, user, or group"

  @moduledoc """
  Attaches a managed IAM policy to a role, user, or group.
  Exactly one of `--to-role`, `--to-user`, or `--to-group` is required.

  ## Usage

      mix aws.iam.attach_policy --policy-arn ARN --to-role ROLE_NAME [options]
      mix aws.iam.attach_policy --policy-arn ARN --to-user USERNAME [options]
      mix aws.iam.attach_policy --policy-arn ARN --to-group GROUP_NAME [options]

  ## Options

    * `--policy-arn` — Policy ARN to attach (required)
    * `--to-role` — Role name to attach the policy to
    * `--to-user` — User name to attach the policy to
    * `--to-group` — Group name to attach the policy to
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.attach_policy --policy-arn arn:aws:iam::aws:policy/AWSLambdaBasicExecutionRole --to-role MyLambdaRole
      mix aws.iam.attach_policy --policy-arn arn:aws:iam::123:policy/MyPolicy --to-user alice
      mix aws.iam.attach_policy --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess --to-group readers
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        policy_arn: :string,
        to_role: :string,
        to_user: :string,
        to_group: :string
      )

    policy_arn = parsed[:policy_arn] || Mix.raise("--policy-arn is required")

    opts = Helpers.build_opts(parsed)

    case {parsed[:to_role], parsed[:to_user], parsed[:to_group]} do
      {role, nil, nil} when is_binary(role) ->
        AWS.IAM.attach_role_policy(role, policy_arn, opts) |> Helpers.handle_result()

      {nil, user, nil} when is_binary(user) ->
        AWS.IAM.attach_user_policy(user, policy_arn, opts) |> Helpers.handle_result()

      {nil, nil, group} when is_binary(group) ->
        AWS.IAM.attach_group_policy(group, policy_arn, opts) |> Helpers.handle_result()

      _ ->
        Mix.raise("Exactly one of --to-role, --to-user, or --to-group is required")
    end
  end
end
