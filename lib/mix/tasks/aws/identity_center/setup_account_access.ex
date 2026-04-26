defmodule Mix.Tasks.AWS.IdentityCenter.SetupAccountAccess do
  @shortdoc "Creates a permission set, attaches a policy, and assigns it to an account + principal"

  @moduledoc """
  High-level task that creates an Identity Center permission set, attaches an
  AWS managed policy, and creates an account assignment granting the specified
  user or group access to an AWS account.

  ## Usage

      mix aws.identity_center.setup_account_access --instance-arn ARN [options]

  ## Options

    * `--instance-arn` — Identity Center instance ARN (required)
    * `--permission-set-name` — Name for the permission set to create (required)
    * `--managed-policy-arn` — AWS managed policy ARN to attach (required)
    * `--account-id` — Target AWS account ID (required)
    * `--principal-type` — `USER` or `GROUP` (required)
    * `--principal-id` — User or group ID from the identity store (required)
    * `--description` — Permission set description
    * `--session-duration` — ISO 8601 session duration (default: `PT8H`)
    * `--force` / `-f` — Proceed even if resources already exist
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.setup_account_access \\
        --instance-arn arn:aws:sso:::instance/ssoins-1 \\
        --permission-set-name AdminAccess \\
        --managed-policy-arn arn:aws:iam::aws:policy/AdministratorAccess \\
        --account-id 123456789012 \\
        --principal-type USER \\
        --principal-id abc123-user-id
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        instance_arn: :string,
        permission_set_name: :string,
        managed_policy_arn: :string,
        account_id: :string,
        principal_type: :string,
        principal_id: :string,
        description: :string,
        session_duration: :string
      )

    instance_arn = parsed[:instance_arn] || Mix.raise("--instance-arn is required")

    permission_set_name =
      parsed[:permission_set_name] || Mix.raise("--permission-set-name is required")

    managed_policy_arn =
      parsed[:managed_policy_arn] || Mix.raise("--managed-policy-arn is required")

    account_id = parsed[:account_id] || Mix.raise("--account-id is required")
    principal_type = parsed[:principal_type] || Mix.raise("--principal-type is required")
    principal_id = parsed[:principal_id] || Mix.raise("--principal-id is required")

    opts = Helpers.build_opts(parsed)
    force = parsed[:force] || false

    ps_opts =
      opts
      |> Helpers.maybe_put(:description, parsed[:description])
      |> Helpers.maybe_put(:session_duration, parsed[:session_duration] || "PT8H")

    # Step 1: Create permission set
    Mix.shell().info("Step 1/3: Creating permission set '#{permission_set_name}'...")

    ps_result =
      Helpers.idempotent(
        permission_set_name,
        fn -> {:error, %{code: :not_found}} end,
        fn ->
          AWS.IdentityCenter.create_permission_set(instance_arn, permission_set_name, ps_opts)
        end,
        force
      )

    if match?({:error, _}, ps_result), do: Helpers.handle_result(ps_result)

    permission_set_arn =
      case ps_result do
        {:ok, %{permission_set_arn: arn}} -> arn
        _ -> nil
      end

    unless permission_set_arn do
      Mix.raise("Could not determine permission set ARN")
    end

    # Step 2: Attach managed policy
    Mix.shell().info("Step 2/3: Attaching managed policy...")

    attach_result =
      AWS.IdentityCenter.attach_managed_policy_to_permission_set(
        instance_arn,
        permission_set_arn,
        managed_policy_arn,
        opts
      )

    if match?({:error, _}, attach_result), do: Helpers.handle_result(attach_result)

    # Step 3: Create account assignment
    Mix.shell().info("Step 3/3: Creating account assignment...")

    assignment = %{
      target_id: account_id,
      target_type: "AWS_ACCOUNT",
      permission_set_arn: permission_set_arn,
      principal_type: principal_type,
      principal_id: principal_id
    }

    assign_result = AWS.IdentityCenter.create_account_assignment(instance_arn, assignment, opts)
    if match?({:error, _}, assign_result), do: Helpers.handle_result(assign_result)

    Mix.shell().info("Done. Account access has been configured.")
  end
end
