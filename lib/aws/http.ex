defmodule AWS.HTTP do
  @moduledoc false

  alias AWS.HTTP

  @default_http_opts [
    decode_body: false,
    retry: false
  ]

  def start_link(opts \\ []) do
    HTTP.Supervisor.start_link(opts)
  end

  def child_spec(opts \\ []) do
    HTTP.Supervisor.child_spec(opts)
  end

  def request(method, url, body, headers, http_opts \\ []) do
    case execute(method, url, body, headers, http_opts) do
      {:ok, %Req.Response{status: status, headers: headers, body: body}} ->
        {:ok,
         %{
           status_code: status,
           headers: flatten_headers(headers),
           body: body
         }}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  defp execute(method, url, body, headers, opts) do
    opts
    |> build()
    |> Req.request(method: method, url: url, body: body, headers: headers)
  end

  defp build(opts) do
    @default_http_opts
    |> Keyword.merge(opts[:request] || [])
    |> Keyword.put(:finch, HTTP.Supervisor.finch_name())
    |> Req.new()
  end

  defp flatten_headers(headers) do
    Enum.flat_map(headers, fn {name, values} ->
      Enum.map(values, &{name, &1})
    end)
  end
end
