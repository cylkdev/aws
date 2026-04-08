defmodule Mix.Tasks.Aws.Helpers do
  @moduledoc false

  @common_switches [region: :string, force: :boolean, event_bus_name: :string]
  @common_aliases [r: :region, f: :force]

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
  Reads region from parsed opts, falling back to Mix config then `AWS.Config.region/0`.
  """
  def build_opts(parsed_opts) do
    region = parsed_opts[:region] || mix_config(:region) || AWS.Config.region()

    [region: region]
    |> maybe_put(:event_bus_name, parsed_opts[:event_bus_name])
  end

  @doc """
  Handles an API result, printing success output or raising on error.
  """
  def handle_result({:ok, result}), do: print_result(result)
  def handle_result({:error, error}), do: Mix.raise("AWS error: #{format_error(error)}")

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
          error
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
        if Enum.any?(targets, &(&1[:id] == target_id)) do
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

  defp print_result(result) when result == %{} do
    Mix.shell().info("OK")
  end

  defp print_result(result) when is_list(result) do
    Enum.each(result, &Mix.shell().info(inspect(&1, pretty: true)))
  end

  defp print_result(result) do
    Mix.shell().info(inspect(result, pretty: true))
  end

  defp format_error(%{message: msg, details: details}) when not is_nil(details) do
    "#{msg} — #{inspect(details)}"
  end

  defp format_error(%{message: msg}), do: msg
  defp format_error(error), do: inspect(error)

  defp mix_config(key) do
    Application.get_env(:aws, key)
  end
end
