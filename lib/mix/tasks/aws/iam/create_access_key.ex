defmodule Mix.Tasks.AWS.IAM.CreateAccessKey do
  @shortdoc "Creates an IAM access key for a user"

  @moduledoc """
  Creates an access key pair for an IAM user. The secret access key is only
  visible at creation time — save it immediately.

  ## Usage

      mix aws.iam.create_access_key --user USER [options]

  ## Options

    * `--user` — User name (required)
    * `--region` / `-r` — AWS region (default: config or `AWS.Config.region/0`)

  ## Examples

      mix aws.iam.create_access_key --user alice
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
    {parsed, _args, _} = Helpers.parse_opts(argv, user: :string)

    username = parsed[:user] || Mix.raise("--user is required")
    opts = Helpers.build_opts(parsed)

    username
    |> AWS.IAM.create_access_key(opts)
    |> Helpers.handle_result()
  end
end
