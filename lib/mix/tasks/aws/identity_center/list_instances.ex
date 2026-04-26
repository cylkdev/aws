defmodule Mix.Tasks.AWS.IdentityCenter.ListInstances do
  @shortdoc "Lists IAM Identity Center instances"

  @moduledoc """
  Lists IAM Identity Center instances accessible in the current AWS account.

  Returns instance ARNs and identity store IDs needed for other Identity Center
  operations.

  ## Usage

      mix aws.identity_center.list_instances [options]

  ## Options

    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.identity_center.list_instances
  """

  use Mix.Task
  alias Mix.Tasks.AWS.Helpers

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _args, _} = Helpers.parse_opts(argv)
    opts = Helpers.build_opts(parsed)

    opts
    |> AWS.IdentityCenter.list_instances()
    |> Helpers.handle_result()
  end
end
