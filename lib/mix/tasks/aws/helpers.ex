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

  @filter_prefix "--filter-"

  @doc """
  Splits client-side `--filter-<field>` flags out of `argv` so they can be
  applied to the parsed response after the API call returns.

  Recognised forms:

    * `--filter-some-field=value`
    * `--filter-some-field value`

  Field names are converted from kebab-case to snake_case atoms (so
  `--filter-lifecycle-state` becomes `:lifecycle_state`). Repeating the same
  filter flag with different values OR-combines those values; using different
  filter keys AND-combines them (handled in `apply_filters/2`).

  Returns `{remaining_argv, filters}` where `filters` is a keyword list
  shaped like `[{field, [value1, value2, ...]}, ...]`.
  """
  @spec extract_filters([String.t()]) :: {[String.t()], keyword([String.t()])}
  def extract_filters(argv) do
    {remaining, pairs} = do_extract(argv, [], [])
    {Enum.reverse(remaining), group_filter_pairs(Enum.reverse(pairs))}
  end

  defp do_extract([], remaining, pairs), do: {remaining, pairs}

  defp do_extract([@filter_prefix <> rest = flag | tail], remaining, pairs) do
    case String.split(rest, "=", parts: 2) do
      [key, value] ->
        do_extract(tail, remaining, [{normalize_filter_key(key), value} | pairs])

      [key] ->
        case tail do
          [value | tail2] when is_binary(value) and value != "" ->
            if String.starts_with?(value, "--") do
              Mix.raise("filter flag #{flag} requires a value")
            else
              do_extract(tail2, remaining, [{normalize_filter_key(key), value} | pairs])
            end

          _ ->
            Mix.raise("filter flag #{flag} requires a value")
        end
    end
  end

  defp do_extract([head | tail], remaining, pairs) do
    do_extract(tail, [head | remaining], pairs)
  end

  defp normalize_filter_key(key) do
    key |> String.replace("-", "_") |> String.to_atom()
  end

  defp group_filter_pairs(pairs) do
    pairs
    |> Enum.reduce([], fn {key, value}, acc ->
      case Keyword.fetch(acc, key) do
        {:ok, values} -> Keyword.put(acc, key, values ++ [value])
        :error -> Keyword.put(acc, key, [value])
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Applies client-side filters extracted by `extract_filters/1` to a parsed
  AWS response.

  The filter walker is generic and AWS-API-agnostic: it traverses the result
  tree, and at every list of maps it encounters, narrows the list to elements
  matching the filters whose keys appear on those elements. Filters with keys
  that don't appear on a given list pass that list through untouched, so a
  filter targets exactly the level(s) of the response where that field exists.

  Comparison is string-based after `to_string/1` on both sides, so values like
  integers, booleans, and atoms compare against their textual form.
  """
  @spec apply_filters({:ok, term} | {:error, term} | term, keyword([String.t()])) ::
          {:ok, term} | {:error, term} | term
  def apply_filters(result, filters)
  def apply_filters(result, []), do: result
  def apply_filters({:ok, value}, filters), do: {:ok, walk(value, filters)}
  def apply_filters({:error, _} = error, _filters), do: error
  def apply_filters(other, filters), do: walk(other, filters)

  defp walk(value, filters) when is_map(value) and not is_struct(value) do
    Map.new(value, fn {k, v} -> {k, walk(v, filters)} end)
  end

  defp walk(list, filters) when is_list(list) do
    list
    |> filter_list(filters)
    |> Enum.map(&walk(&1, filters))
  end

  defp walk(other, _filters), do: other

  defp filter_list(list, filters) do
    if list_of_plain_maps?(list) do
      Enum.reduce(filters, list, fn {key, accepted_values}, acc ->
        if Enum.any?(acc, &Map.has_key?(&1, key)) do
          Enum.filter(acc, fn elem ->
            actual = to_string(Map.get(elem, key, ""))
            Enum.any?(accepted_values, &(&1 == actual))
          end)
        else
          acc
        end
      end)
    else
      list
    end
  end

  defp list_of_plain_maps?([]), do: false

  defp list_of_plain_maps?(list) do
    Enum.all?(list, fn elem -> is_map(elem) and not is_struct(elem) end)
  end

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
