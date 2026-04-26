defmodule Mix.Tasks.AWS.IAM.SetupRole do
  @shortdoc "Creates a role, creates a policy, and attaches the policy"

  @moduledoc """
  High-level task that creates an IAM role with a trust policy, creates a
  managed policy with the given permissions, and attaches the policy to the
  role. Each step is idempotent by default.

  ## Usage

      mix aws.iam.setup_role --name ROLE_NAME \\
        --trust-policy JSON \\
        --policy-name POLICY_NAME \\
        --policy-document JSON \\
        [options]

  ## Options

    * `--name` — Role name (required)
    * `--trust-policy` — JSON trust policy (required)
    * `--policy-name` — Name for the managed policy to create and attach (required)
    * `--policy-document` — JSON permissions policy document (required)
    * `--role-description` — Description for the role
    * `--policy-description` — Description for the policy
    * `--force` / `-f` — Update resources if they already exist
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.setup_role --name MyLambdaRole \\
        --trust-policy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \\
        --policy-name MyLambdaPolicy \\
        --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"*"}]}'
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        name: :string,
        trust_policy: :string,
        policy_name: :string,
        policy_document: :string,
        role_description: :string,
        policy_description: :string
      )

    role_name = parsed[:name] || Mix.raise("--name is required")

    trust_policy_json = parsed[:trust_policy] || Mix.raise("--trust-policy is required")
    policy_name = parsed[:policy_name] || Mix.raise("--policy-name is required")
    policy_json = parsed[:policy_document] || Mix.raise("--policy-document is required")

    trust_policy =
      try do
        :json.decode(trust_policy_json)
      rescue
        _ -> Mix.raise("--trust-policy is not valid JSON")
      end

    policy_document =
      try do
        :json.decode(policy_json)
      rescue
        _ -> Mix.raise("--policy-document is not valid JSON")
      end

    opts = Helpers.build_opts(parsed)
    force = parsed[:force] || false

    role_opts = Helpers.maybe_put(opts, :description, parsed[:role_description])
    policy_opts = Helpers.maybe_put(opts, :description, parsed[:policy_description])

    # Step 1: Create role
    Mix.shell().info("Step 1/3: Creating role '#{role_name}'...")

    role_result =
      Helpers.idempotent(
        role_name,
        fn -> AWS.IAM.get_role(role_name, opts) end,
        fn -> AWS.IAM.create_role(role_name, trust_policy, role_opts) end,
        force
      )

    if match?({:error, _}, role_result), do: Helpers.handle_result(role_result)

    # Step 2: Create policy
    Mix.shell().info("Step 2/3: Creating policy '#{policy_name}'...")

    idempotent_result =
      Helpers.idempotent(
        policy_name,
        fn -> check_existing_policy(role_result, policy_name, opts) end,
        fn -> create_new_policy(policy_name, policy_document, policy_opts) end,
        force
      )

    {policy_arn, policy_result} = unwrap_policy_result(idempotent_result)

    if match?({:error, _}, policy_result), do: Helpers.handle_result(policy_result)

    # Step 3: Attach policy to role
    Mix.shell().info("Step 3/3: Attaching policy to role...")

    attach_result =
      Helpers.idempotent(
        "#{role_name}/#{policy_name}",
        fn -> check_policy_attached(role_name, policy_arn, opts) end,
        fn -> AWS.IAM.attach_role_policy(role_name, policy_arn, opts) end,
        force
      )

    if match?({:error, _}, attach_result), do: Helpers.handle_result(attach_result)

    Mix.shell().info("Done. Role '#{role_name}' is ready.")
  end

  defp check_existing_policy(role_result, policy_name, opts) do
    account_id = extract_account_id(role_result)
    arn = "arn:aws:iam::#{account_id}:policy/#{policy_name}"

    case AWS.IAM.get_policy(arn, opts) do
      {:ok, p} -> {:ok, {:existing, p[:arn]}}
      error -> error
    end
  end

  defp create_new_policy(policy_name, policy_document, policy_opts) do
    case AWS.IAM.create_policy(policy_name, policy_document, policy_opts) do
      {:ok, p} -> {:ok, {:created, p[:arn]}}
      error -> error
    end
  end

  defp check_policy_attached(role_name, policy_arn, opts) do
    case AWS.IAM.list_attached_role_policies(role_name, opts) do
      {:ok, %{policies: policies}} -> policy_attached_result(policies, policy_arn)
      error -> error
    end
  end

  defp policy_attached_result(policies, policy_arn) do
    if Enum.any?(policies, &(&1[:policy_arn] === policy_arn)) do
      {:ok, %{}}
    else
      {:error, %{code: :not_found}}
    end
  end

  defp extract_account_id({:ok, %{arn: arn}}) when is_binary(arn) do
    arn |> String.split(":") |> Enum.at(4)
  end

  defp extract_account_id(_), do: "unknown"

  defp unwrap_policy_result(:skipped), do: {nil, :skipped}
  defp unwrap_policy_result({:ok, {:existing, arn}}), do: {arn, {:ok, %{}}}
  defp unwrap_policy_result({:ok, {:created, arn}}), do: {arn, {:ok, %{}}}
  defp unwrap_policy_result({:error, _} = err), do: {nil, err}
end
