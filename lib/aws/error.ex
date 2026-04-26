defmodule AWS.Error do
  @moduledoc """
  Error helpers that delegate to the `ErrorMessage` library.

  HTTP 4xx responses map to `not_found`, 5xx responses map to
  `service_unavailable`, and any other failures map to
  `internal_server_error`. The adapter module is configurable via the
  `:error_message_adapter` option (defaulting to `ErrorMessage`).
  """

  def bad_request(message, details, opts) do
    adapter(opts).bad_request(message, details)
  end

  def conflict(message, details, opts) do
    adapter(opts).conflict(message, details)
  end

  def forbidden(message, details, opts) do
    adapter(opts).forbidden(message, details)
  end

  def internal_server_error(message, details, opts) do
    adapter(opts).internal_server_error(message, details)
  end

  def not_found(message, details, opts) do
    adapter(opts).not_found(message, details)
  end

  def service_unavailable(message, details, opts) do
    adapter(opts).service_unavailable(message, details)
  end

  def unauthorized(message, details, opts) do
    adapter(opts).unauthorized(message, details)
  end

  defp adapter(opts) do
    opts[:error_message_adapter] || ErrorMessage
  end
end
