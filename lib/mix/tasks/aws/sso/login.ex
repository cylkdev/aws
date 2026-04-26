defmodule Mix.Tasks.AWS.SSO.Login do
  @shortdoc "Runs the AWS SSO device-code login flow for a profile"

  @moduledoc """
  Runs the AWS SSO (Identity Center) OIDC device-code flow for the
  given profile, writing the refreshed token cache under
  `~/.aws/sso/cache/`.

  ## Usage

      mix aws.sso.login --profile dev

  ## Switches

    * `--profile` — profile name in `~/.aws/config`; defaults to
      `$AWS_PROFILE` or `default`.
  """

  use Mix.Task

  alias AWS.Credentials.Profile
  alias AWS.Credentials.SSO.Login

  @switches [profile: :string]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, _args, _invalid} = OptionParser.parse(argv, strict: @switches)
    profile = opts[:profile] || Profile.default()

    case Login.run(profile, skip_browser_open: false) do
      {:ok, _cache} ->
        Mix.shell().info("SSO login complete for profile '#{profile}'.")

      {:error, reason} ->
        Mix.raise("SSO login failed: #{inspect(reason)}")
    end
  end
end
