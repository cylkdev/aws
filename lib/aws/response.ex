defmodule AWS.Response do
  @moduledoc false

  # Shared `deserialize_response/3` for every service. The status picks the
  # `ErrorMessage` constructor; AWS's own error code is kept in the details
  # so callers can tell `AccessDenied` from a real 404.

  import SweetXml, only: [xpath: 2, sigil_x: 2]

  def handle({:ok, body}, _opts, parser) do
    case parser.(body) do
      {:error, _} = error -> error
      {:ok, _} = ok -> ok
      result -> {:ok, result}
    end
  end

  def handle({:error, {:http_error, status, response}}, _opts, _parser) do
    {:error, error(status, response)}
  end

  def handle({:error, reason}, _opts, _parser) do
    {:error, ErrorMessage.internal_server_error("internal server error", %{reason: reason})}
  end

  def error(status, response) do
    %{code: code, message: message} = parse(response)
    details = %{code: code, status: status, response: response}

    case status do
      400 -> ErrorMessage.bad_request(message, details)
      401 -> ErrorMessage.unauthorized(message, details)
      403 -> ErrorMessage.forbidden(message, details)
      404 -> ErrorMessage.not_found(message, details)
      409 -> ErrorMessage.conflict(message, details)
      412 -> ErrorMessage.precondition_failed(message, details)
      429 -> ErrorMessage.too_many_requests(message, details)
      s when s in 400..499 -> ErrorMessage.bad_request(message, details)
      503 -> ErrorMessage.service_unavailable(message, details)
      s when s >= 500 -> ErrorMessage.internal_server_error(message, details)
      _ -> ErrorMessage.internal_server_error(message, details)
    end
  end

  # XML services use <Error><Code>/<Message>; JSON 1.1 uses __type/message.
  def parse(body) when is_binary(body) do
    if body |> String.trim_leading() |> String.starts_with?("<") do
      %{
        code: xml(body, ~x"//Error/Code/text()"s),
        message: xml(body, ~x"//Error/Message/text()"s)
      }
    else
      json(body)
    end
  end

  # The JSON services decode the error body before handing it over.
  def parse(%{} = map), do: %{code: type(map["__type"]), message: map["message"] || ""}

  def parse(_body), do: %{code: "", message: ""}

  defp xml(body, path) do
    xpath(body, path)
  rescue
    _ -> ""
  end

  defp json(body) do
    case :json.decode(body) do
      %{} = map -> %{code: type(map["__type"]), message: map["message"] || ""}
      _ -> %{code: "", message: ""}
    end
  rescue
    _ -> %{code: "", message: ""}
  end

  # "com.amazonaws.logs#ThrottlingException" -> "ThrottlingException"
  defp type(nil), do: ""
  defp type(t) when is_binary(t), do: t |> String.split("#") |> List.last()
  defp type(_), do: ""
end
