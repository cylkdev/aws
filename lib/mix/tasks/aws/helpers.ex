defmodule Mix.Tasks.AWS.Helpers do
  @moduledoc false

  @common_switches [
    region: :string,
    force: :boolean,
    event_bus_name: :string,
    profile: :string,
    access_key_id: :string,
    secret_access_key: :string,
    session_token: :string
  ]
  @common_aliases [r: :region, f: :force, p: :profile]

  @doc """
  Parses argv with common AWS switches plus any task-specific ones.
  Returns `{parsed_opts, remaining_args, invalid}`.
  """
  def parse_opts(argv, extra_switches \\ []) do
    OptionParser.parse(argv,
      strict: @common_switches ++ extra_switches,
      aliases: @common_aliases
    )
  end

  @doc """
  Builds the keyword list passed to API calls from parsed opts.

  Credential handling (mirrors ex_aws flat top-level shape):

    * `--profile dev` → injects `{:awscli, "dev", 30}` for all four credential
      fields; the `:awscli` source returns a map that populates
      `:access_key_id`, `:secret_access_key`, `:security_token`, and `:region`
      from `~/.aws/config` / `~/.aws/credentials`.
    * `--access-key-id` + `--secret-access-key` (+ optional `--session-token`)
      → injects literals at the top level.
    * Neither → omits credential opts so `AWS.Config.new/2` defaults kick in
      (env vars → IMDS → ECS).

  Region resolution prefers `--region`, then Mix config, then
  `AWS.Config.region/0`.
  """
  def build_opts(parsed_opts) do
    []
    |> maybe_put(:event_bus_name, parsed_opts[:event_bus_name])
    |> put_credentials(parsed_opts)
    |> put_region(parsed_opts)
  end

  defp put_credentials(opts, parsed_opts) do
    cond do
      parsed_opts[:profile] ->
        source = {:awscli, parsed_opts[:profile], 30}

        opts
        |> Keyword.put(:access_key_id, source)
        |> Keyword.put(:secret_access_key, source)
        |> Keyword.put(:security_token, source)
        |> Keyword.put(:region, source)

      parsed_opts[:access_key_id] && parsed_opts[:secret_access_key] ->
        opts
        |> Keyword.put(:access_key_id, parsed_opts[:access_key_id])
        |> Keyword.put(:secret_access_key, parsed_opts[:secret_access_key])
        |> maybe_put(:security_token, parsed_opts[:session_token])

      true ->
        opts
    end
  end

  # --region wins if explicit; otherwise let the awscli source (from --profile)
  # or default chain supply it.
  defp put_region(opts, parsed_opts) do
    cond do
      parsed_opts[:region] ->
        Keyword.put(opts, :region, parsed_opts[:region])

      Keyword.has_key?(opts, :region) ->
        opts

      region = mix_config(:region) ->
        Keyword.put(opts, :region, region)

      true ->
        Keyword.put(opts, :region, AWS.Config.region())
    end
  end

  @doc """
  Handles an API result, printing success output or raising on error.

  On error, prints the full error (code, message, details) to stderr so the
  failure is visible even when Mix truncates its own error message, then
  raises to fail the task with a non-zero exit code.
  """
  def handle_result({:ok, result}), do: print_result(result)

  def handle_result({:error, error}) do
    Mix.shell().error("AWS error:")
    Mix.shell().error(format_error(error))
    Mix.raise("AWS API call failed")
  end

  @doc """
  Checks whether a resource already exists before creating it.

  - Without `--force`: if the resource exists, prints a skip message and returns `:skipped`.
    If it does not exist (`:not_found`), calls `action_fn` and returns its result.
  - With `--force`: always calls `action_fn`.
  """
  def idempotent(name, check_fn, action_fn, force) do
    if force do
      action_fn.()
    else
      case check_fn.() do
        {:ok, _} ->
          Mix.shell().info("'#{name}' already exists, skipping (use --force to update)")
          :skipped

        {:error, %{code: :not_found}} ->
          action_fn.()

        {:error, _} = error ->
          handle_result(error)
      end
    end
  end

  @doc """
  Checks whether a target with `target_id` exists on `rule`. Returns `{:ok, %{}}` if found,
  `{:error, %{code: :not_found}}` if not. Used by `idempotent/4` for target checks.
  """
  def find_target(rule, target_id, opts) do
    case AWS.EventBridge.list_targets_by_rule(rule, opts) do
      {:ok, %{targets: targets}} ->
        if Enum.any?(targets, &(&1[:id] === target_id)) do
          {:ok, %{}}
        else
          {:error, %{code: :not_found}}
        end

      error ->
        error
    end
  end

  @doc false
  def maybe_put(opts, _key, nil), do: opts
  def maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp print_result(result) when result === %{} do
    Mix.shell().info("OK")
  end

  defp print_result(result) when is_list(result) do
    Enum.each(result, &Mix.shell().info(inspect(&1, pretty: true)))
  end

  defp print_result(result) do
    result
    |> inspect(pretty: true)
    |> Mix.shell().info()
  end

  defp format_error(%{code: code, message: msg, details: details}) when not is_nil(details) do
    """
      code:    #{inspect(code)}
      message: #{msg}
      details: #{inspect(details, pretty: true, limit: :infinity)}\
    """
  end

  defp format_error(%{code: code, message: msg}) do
    """
      code:    #{inspect(code)}
      message: #{msg}\
    """
  end

  defp format_error(%{message: msg, details: details}) when not is_nil(details) do
    """
      message: #{msg}
      details: #{inspect(details, pretty: true, limit: :infinity)}\
    """
  end

  defp format_error(%{message: msg}), do: "  message: #{msg}"
  defp format_error(error), do: "  " <> inspect(error, pretty: true, limit: :infinity)

  defp mix_config(key) do
    Application.get_env(:aws, key)
  end
end
