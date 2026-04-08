defmodule Mix.Tasks.Aws.Iam.ListPolicies do
  @shortdoc "Lists managed IAM policies"

  @moduledoc """
  Lists managed IAM policies.

  ## Usage

      mix aws.iam.list_policies [options]

  ## Options

    * `--scope` — `All`, `AWS`, or `Local` (default: `Local`)
    * `--only-attached` — Only list policies attached to an entity
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.list_policies
      mix aws.iam.list_policies --scope All
      mix aws.iam.list_policies --only-attached
  """

  use Mix.Task
  alias Mix.Tasks.Aws.Helpers

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:aws)

    {parsed, _args, _} =
      Helpers.parse_opts(argv,
        scope: :string,
        only_attached: :boolean
      )

    opts =
      Helpers.build_opts(parsed)
      |> Helpers.maybe_put(:scope, parsed[:scope])
      |> Helpers.maybe_put(:only_attached, parsed[:only_attached])

    AWS.IAM.list_policies(opts)
    |> Helpers.handle_result()
  end
end
