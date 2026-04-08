defmodule AWS.CloudWatch do
  @moduledoc """
  `AWS.CloudWatch` provides an API for Amazon CloudWatch.

  This API is a wrapper for `ExAws.Cloudwatch`. It provides consistent error
  handling, response deserialization, and sandbox support.

  ## Shared Options

  The following options are available for most functions in this API:

    - `:region` - The AWS region. Defaults to `AWS.Config.region()`.

    - `:cloudwatch` - A keyword list of options used to configure the ExAws CloudWatch service.
      See `ExAws.Config.new/2` for available options.

    - `:sandbox` - A keyword list to override sandbox configuration.
        - `:enabled` - Whether sandbox mode is enabled.
        - `:mode` - `:local` or `:inline`.
        - `:scheme` - The sandbox scheme.
        - `:host` - The sandbox host.
        - `:port` - The sandbox port.

  ## Sandbox

  Set `sandbox: [enabled: true, mode: :inline]` to activate inline sandbox mode.

  ### Setup

  Add the following to your `test_helper.exs`:

      AWS.CloudWatch.Sandbox.start_link()

  ### Usage

      setup do
        AWS.CloudWatch.Sandbox.set_describe_alarms_responses([
          fn -> {:ok, %{metric_alarms: []}} end
        ])
      end

      test "describes alarms" do
        assert {:ok, %{metric_alarms: []}} =
                 AWS.CloudWatch.describe_alarms(sandbox: [enabled: true, mode: :inline])
      end
  """

  alias AWS.{Config, Error, Serializer}
  alias ExAws.Cloudwatch, as: API

  @custom_opts [:region, :cloudwatch, :sandbox]

  # Alarms

  @doc """
  Creates or updates a metric alarm.

  ## Arguments

    * `alarm_name` - The alarm name.
    * `comparison_operator` - e.g., `"GreaterThanThreshold"`, `"LessThanThreshold"`.
    * `evaluation_periods` - Number of periods to evaluate.
    * `metric_name` - e.g., `"FailedInvocations"`.
    * `namespace` - e.g., `"AWS/Events"`.
    * `period` - Evaluation period in seconds.
    * `threshold` - Threshold value.
    * `statistic` - e.g., `"Sum"`, `"Average"`.
    * `opts` - Options including `:alarm_description`, `:alarm_actions`, `:ok_actions`,
      `:insufficient_data_actions`, `:dimensions`, `:treat_missing_data`, plus shared options.
  """
  @spec put_metric_alarm(
          alarm_name :: String.t(),
          comparison_operator :: String.t(),
          evaluation_periods :: pos_integer(),
          metric_name :: String.t(),
          namespace :: String.t(),
          period :: pos_integer(),
          threshold :: number(),
          statistic :: String.t(),
          opts :: keyword()
        ) :: {:ok, %{}} | {:error, term()}
  def put_metric_alarm(alarm_name, comparison_operator, evaluation_periods, metric_name, namespace, period, threshold, statistic, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_metric_alarm_response(alarm_name, comparison_operator, evaluation_periods, metric_name, namespace, period, threshold, statistic, opts)
    else
      do_put_metric_alarm(alarm_name, comparison_operator, evaluation_periods, metric_name, namespace, period, threshold, statistic, opts)
    end
  end

  defp do_put_metric_alarm(alarm_name, comparison_operator, evaluation_periods, metric_name, namespace, period, threshold, statistic, opts) do
    {api_opts, config_opts} = split_opts(opts)

    alarm_name
    |> API.put_metric_alarm(comparison_operator, evaluation_periods, metric_name, namespace, period, threshold, statistic, api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Lists alarms with optional filters.

  ## Options

    * `:alarm_names` - List of alarm names.
    * `:alarm_name_prefix` - Filter by prefix.
    * `:state_value` - Filter by state.
    * `:action_prefix` - Filter by action prefix.
    * `:max_records` - Maximum number of results.
    * `:next_token` - Pagination token.
  """
  @spec describe_alarms(opts :: keyword()) :: {:ok, map()} | {:error, term()}
  def describe_alarms(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_alarms_response(opts)
    else
      do_describe_alarms(opts)
    end
  end

  defp do_describe_alarms(opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.describe_alarms(api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Returns alarms for a specific metric.
  """
  @spec describe_alarms_for_metric(metric_name :: String.t(), namespace :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def describe_alarms_for_metric(metric_name, namespace, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_alarms_for_metric_response(metric_name, namespace, opts)
    else
      do_describe_alarms_for_metric(metric_name, namespace, opts)
    end
  end

  defp do_describe_alarms_for_metric(metric_name, namespace, opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.describe_alarms_for_metric(metric_name, namespace, api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Returns alarm state change history.

  ## Options

    * `:alarm_name` - Filter by alarm name.
    * `:history_item_type` - Filter by history type.
    * `:start_date` - Start of date range.
    * `:end_date` - End of date range.
    * `:max_records` - Maximum results.
    * `:next_token` - Pagination token.
  """
  @spec describe_alarm_history(opts :: keyword()) :: {:ok, map()} | {:error, term()}
  def describe_alarm_history(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_alarm_history_response(opts)
    else
      do_describe_alarm_history(opts)
    end
  end

  defp do_describe_alarm_history(opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.describe_alarm_history(api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Deletes alarms by name.
  """
  @spec delete_alarms(alarm_names :: list(String.t()), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_alarms(alarm_names, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_alarms_response(alarm_names, opts)
    else
      do_delete_alarms(alarm_names, opts)
    end
  end

  defp do_delete_alarms(alarm_names, opts) do
    {_api_opts, config_opts} = split_opts(opts)

    alarm_names
    |> API.delete_alarms()
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Enables actions on the specified alarms.
  """
  @spec enable_alarm_actions(alarm_names :: list(String.t()), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def enable_alarm_actions(alarm_names, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_enable_alarm_actions_response(alarm_names, opts)
    else
      do_enable_alarm_actions(alarm_names, opts)
    end
  end

  defp do_enable_alarm_actions(alarm_names, opts) do
    {_api_opts, config_opts} = split_opts(opts)

    alarm_names
    |> API.enable_alarm_actions()
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Disables actions on the specified alarms.
  """
  @spec disable_alarm_actions(alarm_names :: list(String.t()), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def disable_alarm_actions(alarm_names, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_disable_alarm_actions_response(alarm_names, opts)
    else
      do_disable_alarm_actions(alarm_names, opts)
    end
  end

  defp do_disable_alarm_actions(alarm_names, opts) do
    {_api_opts, config_opts} = split_opts(opts)

    alarm_names
    |> API.disable_alarm_actions()
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  # Metrics

  @doc """
  Retrieves metric data points.

  ## Arguments

    * `namespace` - e.g., `"AWS/Events"`.
    * `metric_name` - e.g., `"Invocations"`.
    * `start_time` - ISO 8601 timestamp.
    * `end_time` - ISO 8601 timestamp.
    * `period` - Period in seconds.
    * `opts` - Options including `:statistics`, `:dimensions`, `:unit`, plus shared options.
  """
  @spec get_metric_statistics(
          namespace :: String.t(),
          metric_name :: String.t(),
          start_time :: String.t(),
          end_time :: String.t(),
          period :: pos_integer(),
          opts :: keyword()
        ) :: {:ok, map()} | {:error, term()}
  def get_metric_statistics(namespace, metric_name, start_time, end_time, period, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_metric_statistics_response(namespace, metric_name, start_time, end_time, period, opts)
    else
      do_get_metric_statistics(namespace, metric_name, start_time, end_time, period, opts)
    end
  end

  defp do_get_metric_statistics(namespace, metric_name, start_time, end_time, period, opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.get_metric_statistics(namespace, metric_name, start_time, end_time, period, api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Discovers available metrics.

  ## Options

    * `:namespace` - Filter by namespace.
    * `:metric_name` - Filter by metric name.
    * `:dimensions` - Filter by dimensions.
    * `:next_token` - Pagination token.
  """
  @spec list_metrics(opts :: keyword()) :: {:ok, map()} | {:error, term()}
  def list_metrics(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_metrics_response(opts)
    else
      do_list_metrics(opts)
    end
  end

  defp do_list_metrics(opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.list_metrics(api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Publishes custom metric data.

  ## Arguments

    * `metric_data` - List of metric datum maps (`:metric_name`, `:value`, `:unit`, etc.).
    * `namespace` - The namespace for the metric data.
    * `opts` - Shared options.
  """
  @spec put_metric_data(metric_data :: list(map()), namespace :: String.t(), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def put_metric_data(metric_data, namespace, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_metric_data_response(metric_data, namespace, opts)
    else
      do_put_metric_data(metric_data, namespace, opts)
    end
  end

  defp do_put_metric_data(metric_data, namespace, opts) do
    {_api_opts, config_opts} = split_opts(opts)

    API.put_metric_data(metric_data, namespace)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  # Dashboards

  @doc """
  Creates or updates a CloudWatch dashboard.

  ## Arguments

    * `dashboard_name` - The dashboard name.
    * `dashboard_body` - JSON string defining the dashboard layout.
    * `opts` - Shared options.
  """
  @spec put_dashboard(dashboard_name :: String.t(), dashboard_body :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def put_dashboard(dashboard_name, dashboard_body, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_dashboard_response(dashboard_name, dashboard_body, opts)
    else
      do_put_dashboard(dashboard_name, dashboard_body, opts)
    end
  end

  defp do_put_dashboard(dashboard_name, dashboard_body, opts) do
    {_api_opts, config_opts} = split_opts(opts)

    API.put_dashboard(dashboard_name, dashboard_body)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Returns the body of a CloudWatch dashboard.
  """
  @spec get_dashboard(dashboard_name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_dashboard(dashboard_name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_dashboard_response(dashboard_name, opts)
    else
      do_get_dashboard(dashboard_name, opts)
    end
  end

  defp do_get_dashboard(dashboard_name, opts) do
    {_api_opts, config_opts} = split_opts(opts)

    API.get_dashboard(dashboard_name: dashboard_name)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Lists CloudWatch dashboards.

  ## Options

    * `:dashboard_name_prefix` - Filter by prefix.
    * `:next_token` - Pagination token.
  """
  @spec list_dashboards(opts :: keyword()) :: {:ok, map()} | {:error, term()}
  def list_dashboards(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_list_dashboards_response(opts)
    else
      do_list_dashboards(opts)
    end
  end

  defp do_list_dashboards(opts) do
    {api_opts, config_opts} = split_opts(opts)

    API.list_dashboards(api_opts)
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  @doc """
  Deletes dashboards by name.
  """
  @spec delete_dashboards(dashboard_names :: list(String.t()), opts :: keyword()) ::
          {:ok, %{}} | {:error, term()}
  def delete_dashboards(dashboard_names, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_dashboards_response(dashboard_names, opts)
    else
      do_delete_dashboards(dashboard_names, opts)
    end
  end

  defp do_delete_dashboards(dashboard_names, opts) do
    {_api_opts, config_opts} = split_opts(opts)

    dashboard_names
    |> API.delete_dashboards()
    |> perform(config_opts)
    |> deserialize_response(config_opts, fn result -> Serializer.deserialize(result) end)
  end

  # Sandbox delegation

  defp inline_sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    sandbox_enabled = sandbox_opts[:enabled] || Config.sandbox_enabled?()
    sandbox_mode = sandbox_opts[:mode] || Config.sandbox_mode()

    sandbox_enabled and sandbox_mode === :inline and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    @doc false
    defdelegate sandbox_disabled?, to: AWS.CloudWatch.Sandbox

    # Alarms
    @doc false
    defdelegate sandbox_put_metric_alarm_response(a, b, c, d, e, f, g, h, opts), to: AWS.CloudWatch.Sandbox, as: :put_metric_alarm_response
    @doc false
    defdelegate sandbox_describe_alarms_response(opts), to: AWS.CloudWatch.Sandbox, as: :describe_alarms_response
    @doc false
    defdelegate sandbox_describe_alarms_for_metric_response(m, n, opts), to: AWS.CloudWatch.Sandbox, as: :describe_alarms_for_metric_response
    @doc false
    defdelegate sandbox_describe_alarm_history_response(opts), to: AWS.CloudWatch.Sandbox, as: :describe_alarm_history_response
    @doc false
    defdelegate sandbox_delete_alarms_response(names, opts), to: AWS.CloudWatch.Sandbox, as: :delete_alarms_response
    @doc false
    defdelegate sandbox_enable_alarm_actions_response(names, opts), to: AWS.CloudWatch.Sandbox, as: :enable_alarm_actions_response
    @doc false
    defdelegate sandbox_disable_alarm_actions_response(names, opts), to: AWS.CloudWatch.Sandbox, as: :disable_alarm_actions_response

    # Metrics
    @doc false
    defdelegate sandbox_get_metric_statistics_response(ns, mn, st, et, p, opts), to: AWS.CloudWatch.Sandbox, as: :get_metric_statistics_response
    @doc false
    defdelegate sandbox_list_metrics_response(opts), to: AWS.CloudWatch.Sandbox, as: :list_metrics_response
    @doc false
    defdelegate sandbox_put_metric_data_response(data, ns, opts), to: AWS.CloudWatch.Sandbox, as: :put_metric_data_response

    # Dashboards
    @doc false
    defdelegate sandbox_put_dashboard_response(name, body, opts), to: AWS.CloudWatch.Sandbox, as: :put_dashboard_response
    @doc false
    defdelegate sandbox_get_dashboard_response(name, opts), to: AWS.CloudWatch.Sandbox, as: :get_dashboard_response
    @doc false
    defdelegate sandbox_list_dashboards_response(opts), to: AWS.CloudWatch.Sandbox, as: :list_dashboards_response
    @doc false
    defdelegate sandbox_delete_dashboards_response(names, opts), to: AWS.CloudWatch.Sandbox, as: :delete_dashboards_response
  else
    defp sandbox_disabled?, do: true

    defp sandbox_put_metric_alarm_response(_, _, _, _, _, _, _, _, _), do: raise("sandbox not available")
    defp sandbox_describe_alarms_response(_), do: raise("sandbox not available")
    defp sandbox_describe_alarms_for_metric_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_describe_alarm_history_response(_), do: raise("sandbox not available")
    defp sandbox_delete_alarms_response(_, _), do: raise("sandbox not available")
    defp sandbox_enable_alarm_actions_response(_, _), do: raise("sandbox not available")
    defp sandbox_disable_alarm_actions_response(_, _), do: raise("sandbox not available")
    defp sandbox_get_metric_statistics_response(_, _, _, _, _, _), do: raise("sandbox not available")
    defp sandbox_list_metrics_response(_), do: raise("sandbox not available")
    defp sandbox_put_metric_data_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_put_dashboard_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_get_dashboard_response(_, _), do: raise("sandbox not available")
    defp sandbox_list_dashboards_response(_), do: raise("sandbox not available")
    defp sandbox_delete_dashboards_response(_, _), do: raise("sandbox not available")
  end

  # Private helpers

  defp perform(operation, opts) do
    ExAws.Operation.perform(operation, cloudwatch_config(opts))
  end

  defp cloudwatch_config(opts) do
    {cw_opts, opts} = Keyword.pop(opts, :cloudwatch, [])
    {sandbox_opts, _opts} = Keyword.pop(opts, :sandbox, [])

    overrides =
      cw_opts
      |> Keyword.put_new(:region, opts[:region] || Config.region())
      |> configure_endpoint(sandbox_opts)

    ExAws.Config.new(:monitoring, overrides)
  end

  defp configure_endpoint(cw_opts, sandbox_opts) do
    sandbox_enabled = sandbox_opts[:enabled] || Config.sandbox_enabled?()
    sandbox_mode = sandbox_opts[:mode] || Config.sandbox_mode()

    if sandbox_enabled and sandbox_mode === :local do
      cw_opts
      |> Keyword.put(:scheme, Config.sandbox_scheme())
      |> Keyword.put(:host, Config.sandbox_host())
      |> Keyword.put(:port, Config.sandbox_port())
      |> Keyword.put_new(:access_key_id, "test")
      |> Keyword.put_new(:secret_access_key, "test")
    else
      maybe_put_credentials(cw_opts)
    end
  end

  defp maybe_put_credentials(opts) do
    opts
    |> Keyword.put_new(:access_key_id, Config.access_key_id())
    |> Keyword.put_new(:secret_access_key, Config.secret_access_key())
  end

  defp deserialize_response({:ok, response}, _opts, func) do
    case func.(response) do
      {:error, _} = error -> error
      {:ok, _} = ok -> ok
      result -> {:ok, result}
    end
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code in 400..499 do
    {:error, Error.not_found("resource not found.", %{response: response}, opts)}
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, opts, _func)
       when status_code >= 500 do
    {:error, Error.service_unavailable("service temporarily unavailable", %{response: response}, opts)}
  end

  defp deserialize_response({:error, reason}, opts, _func) do
    {:error, Error.internal_server_error("internal server error", %{reason: reason}, opts)}
  end

  # Splits our custom opts from API-passthrough opts
  defp split_opts(opts) do
    {Keyword.drop(opts, @custom_opts), Keyword.take(opts, @custom_opts)}
  end
end
