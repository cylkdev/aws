defmodule AWS.Adapters.HTTP.HTTPC do
  @moduledoc """
  HTTP adapter based on erlang's `:httpc`.

  ## Getting Started

  To use erlang httpc you must add the applications `inets`, `ssl`, `public_key`
  to the `extra_applications` in your `mix.exs` file.

  ```elixir
  # mix.exs

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :public_key],
      mod: {AWS.Application, []}
    ]
  end
  ```


  ## Usage

      AWS.Adapters.HTTP.HTTPC.get("https://catfact.ninja/breeds")
  """

  @five_seconds 5_000

  @default_name :aws_adapter_http_httpc
  @default_options [name: @default_name]

  @type method :: :head | :get | :put | :patch | :post | :trace | :options | :delete
  @type url :: String.t()
  @type body :: nil | map() | String.t() | any()
  @type headers :: [{String.t(), String.t()}, ...] | list()
  @type options :: Keyword.t()

  @type response ::
          %AWS.Adapter.HTTP.Response{
            status: non_neg_integer(),
            body: body(),
            headers: list(String.t()),
            request: %AWS.Adapter.HTTP.Request{
              scheme: String.t(),
              host: String.t(),
              port: non_neg_integer(),
              path: String.t(),
              query: String.t(),
              body: body(),
              headers: list(String.t())
            }
          }

  @doc """
  ...
  """
  @spec head(url(), headers(), options()) ::
          {:ok, {body(), response()}} | {:error, ErrorMessage.t() | any()}
  def head(url, headers \\ [], options \\ []) do
    request(:head, url, nil, headers, options)
  end

  @doc """
  ...
  """
  @spec get(url(), headers(), options()) ::
          {:ok, {body(), response()}} | {:error, ErrorMessage.t() | any()}
  def get(url, headers \\ [], options \\ []) do
    request(:get, url, nil, headers, options)
  end

  @doc """
  ...
  """
  @spec put(url(), body(), headers(), options()) ::
          {:ok, {body(), response()}} | {:error, ErrorMessage.t() | any()}
  def put(url, body, headers \\ [], options \\ []) do
    request(:put, url, body, headers, options)
  end

  @doc """
  ...
  """
  @spec patch(url(), body(), headers(), options()) ::
          {:ok, {body(), response()}} | {:error, ErrorMessage.t() | any()}
  def patch(url, body, headers \\ [], options \\ []) do
    request(:patch, url, body, headers, options)
  end

  @doc """
  ...
  """
  @spec post(url(), body(), headers(), options()) ::
          {:ok, {body(), response()}} | {:error, ErrorMessage.t() | any()}
  def post(url, body, headers \\ [], options \\ []) do
    request(:post, url, body, headers, options)
  end

  @doc """
  ...
  """
  @spec trace(url(), headers(), options()) ::
          {:ok, {body(), response()}} | {:error, ErrorMessage.t() | any()}
  def trace(url, headers \\ [], options \\ []) do
    request(:trace, url, nil, headers, options)
  end

  @doc """
  ...
  """
  @spec options(url(), headers(), options()) ::
          {:ok, {body(), response()}} | {:error, ErrorMessage.t() | any()}
  def options(url, headers \\ [], options \\ []) do
    request(:options, url, nil, headers, options)
  end

  @doc """
  ...
  """
  @spec delete(url(), headers(), options()) ::
          {:ok, {body(), response()}} | {:error, ErrorMessage.t() | any()}
  def delete(url, headers \\ [], options \\ []) do
    request(:delete, url, nil, headers, options)
  end

  @doc """
  ...
  """
  @spec request(method(), url(), body(), headers(), options()) ::
          {:ok, {body(), response()}} | {:error, ErrorMessage.t() | any()}
  def request(method, url, body \\ nil, headers \\ [], options \\ [])

  def request(:head, url, _body, headers, options) do
    build_and_make_request(:head, url, nil, headers, options)
  end

  def request(:get, url, _body, headers, options) do
    build_and_make_request(:get, url, nil, headers, options)
  end

  def request(:put, url, body, headers, options) do
    build_and_make_request(:put, url, body, headers, options)
  end

  def request(:patch, url, body, headers, options) do
    build_and_make_request(:patch, url, body, headers, options)
  end

  def request(:post, url, body, headers, options) do
    build_and_make_request(:post, url, body, headers, options)
  end

  def request(:trace, url, _body, headers, options) do
    build_and_make_request(:trace, url, nil, headers, options)
  end

  def request(:options, url, _body, headers, options) do
    build_and_make_request(:options, url, nil, headers, options)
  end

  def request(:delete, url, _body, headers, options) do
    build_and_make_request(:delete, url, nil, headers, options)
  end

  defp build_and_make_request(method, url, body, headers, options) do
    options = Keyword.merge(@default_options, options)

    fn ->
      url
      |> append_query_params(options[:params])
      |> then(&make_httpc_request(method, &1, body, headers, options))
    end
    |> run_and_measure(method, headers, options)
    |> handle_response(options)
  end

  defp append_query_params(url, nil), do: url

  defp append_query_params(url, params) do
    "#{url}?#{params |> encode_query_params |> Enum.join("&")}"
  end

  defp encode_query_params(params) do
    Enum.flat_map(params, fn
      {k, v} when is_list(v) -> Enum.map(v, &encode_key_value(k, &1))
      {k, v} -> [encode_key_value(k, v)]
    end)
  end

  defp encode_key_value(key, value), do: URI.encode_query(%{key => value})

  defp make_httpc_request(method, url, body, headers, options) do
    http_options = [
      timeout: @five_seconds,
      connect_timeout: @five_seconds,
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]

    httpc_request =
      if body do
        content_type = options[:http][:content_type] || "application/json"
        {to_charlist(url), headers, content_type, body}
      else
        {to_charlist(url), headers}
      end

    options = [:http][:httpc] || []

    case :httpc.request(method, httpc_request, http_options, options) do
      {:ok, {{_protocol, status, _http_status_string}, response_headers, response_body}} ->
        uri = URI.parse(url)

        {:ok,
         %AWS.Adapter.HTTP.Response{
           status: status,
           body: response_body,
           headers: response_headers,
           request: %AWS.Adapter.HTTP.Request{
             scheme: uri.scheme,
             host: uri.host,
             port: uri.port,
             path: uri.path,
             query: uri.query,
             body: body,
             headers: headers
           }
         }}

      {:error, _} = e ->
        e
    end
  end

  defp run_and_measure(fnc, method, headers, options) do
    start_time = System.monotonic_time()
    system_time = System.system_time()

    response = fnc.()

    metadata = %{
      start_time: system_time,
      request: %{
        method: method |> to_string() |> String.upcase(),
        headers: headers
      },
      response: response,
      options: options
    }

    end_time = System.monotonic_time()
    measurements = %{elapsed_time: end_time - start_time}
    :telemetry.execute([:http, Keyword.get(options, :name)], measurements, metadata)

    response
  end

  defp handle_response(
         {:ok, %AWS.Adapter.HTTP.Response{status: status, body: body} = response},
         opts
       )
       when status in 200..201 do
    if opts[:disable_json?] do
      {:ok, response}
    else
      case Jason.decode(body) do
        {:ok, decoded} ->
          decoded
          |> ProperCase.to_snake_case()
          |> maybe_atomize_keys(opts)
          |> then(&{:ok, {&1, response}})

        {:error, e} ->
          {:error,
           ErrorMessage.internal_server_error("API did not return valid JSON", %{error: e})}
      end
    end
  end

  defp handle_response({:ok, %AWS.Adapter.HTTP.Response{status: 204} = raw_data}, _opts) do
    {:ok, raw_data}
  end

  defp handle_response({:ok, %{status: code} = res}, opts) do
    api_name = opts[:name]
    details = %{response: res, http_code: code, api_name: api_name}
    error_code_map = error_code_map(api_name)

    if Map.has_key?(error_code_map, code) do
      {error, message} = Map.get(error_code_map, code)

      {:error, apply(ErrorMessage, error, [message, details])}
    else
      message = unknown_error_message(api_name)
      {:error, ErrorMessage.internal_server_error(message, details)}
    end
  end

  defp handle_response({:ok, data}, _opts) do
    {:ok, data}
  end

  defp handle_response({:error, e}, opts) when is_binary(e) or is_atom(e) do
    message = "#{opts[:name]}: #{e}"
    {:error, ErrorMessage.internal_server_error(message, %{error: e})}
  end

  defp handle_response({:error, e}, opts) do
    message = unknown_error_message(opts[:name])
    {:error, ErrorMessage.internal_server_error(message, %{error: e})}
  end

  def unknown_error_message(api_name) do
    "#{api_name}: unknown error occurred"
  end

  def error_code_map(api_name) do
    %{
      400 => {:bad_request, "#{api_name}: bad request"},
      401 => {:unauthorized, "#{api_name}: unauthorized request"},
      403 => {:forbidden, "#{api_name}: forbidden"},
      404 => {:not_found, "#{api_name}: there's nothing to see here :("},
      405 => {:method_not_allowed, "#{api_name}: method not allowed"},
      415 => {:unsupported_media_type, "#{api_name}: unsupported media type in request"},
      429 => {:too_many_requests, "#{api_name}: exceeded rate limit"},
      500 => {:internal_server_error, "#{api_name}: internal server error during request"},
      502 => {:bad_gateway, "#{api_name}: bad gateway"},
      503 => {:service_unavailable, "#{api_name}: service unavailable"},
      504 => {:gateway_timeout, "#{api_name}: gateway timeout"}
    }
  end

  defp maybe_atomize_keys(res, opts) do
    if opts[:atomize_keys?] do
      AWS.Util.atomize_keys(res)
    else
      res
    end
  end
end
