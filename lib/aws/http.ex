defmodule AWS.HTTP do
  @moduledoc """
  This module is responsible for invoking the HTTP adapter functions
  and sandboxing requests during tests.

  On success this module expects one of the following results:

  - `{:ok, %{status: status, body: body, headers: headers}}`
  - `{:ok, {decoded_body, %{status: status, headers: headers}}}`

  and outputs response to:

  - `{:ok, %{status: status, body: body, headers: headers}}`

  On success error is expected to be in the format `{:error, term()}`

  ## Examples

      AWS.HTTP.get("https://catfact.ninja/breeds")

  ## Adapters

  To create your own adapter add the following line:

  ```elixir
  defmodule YourHTTP do
    use AWS.Adapter.HTTP
  end
  ```
  """

  @default_http_adapter AWS.Adapters.HTTP.HTTPC
  @sandbox_enabled Mix.env() === :test

  def head(url, options \\ []) do
    http_adapter =
      if options[:http][:adapter], do: options[:http][:adapter], else: @default_http_adapter

    sandbox? =
      if options[:http][:sandbox], do: options[:http][:sandbox], else: @sandbox_enabled

    headers = build_headers(options)

    if sandbox? and !sandbox_disabled?() do
      sandbox_head_response(url, headers, options)
    else
      if function_exported?(http_adapter, :head, 3) do
        http_adapter.head(url, headers, options)
      else
        http_adapter.request(:head, url, nil, headers, options)
      end
      |> handle_response()
    end
  end

  def get(url, options \\ []) do
    http_adapter =
      if options[:http][:adapter], do: options[:http][:adapter], else: @default_http_adapter

    sandbox? =
      if options[:http][:sandbox], do: options[:http][:sandbox], else: @sandbox_enabled

    headers = build_headers(options)

    if sandbox? and !sandbox_disabled?() do
      sandbox_get_response(url, headers, options)
    else
      if function_exported?(http_adapter, :get, 3) do
        http_adapter.get(url, headers, options)
      else
        http_adapter.request(:get, url, nil, headers, options)
      end
      |> handle_response()
    end
  end

  def delete(url, options \\ []) do
    http_adapter =
      if options[:http][:adapter], do: options[:http][:adapter], else: @default_http_adapter

    sandbox? =
      if options[:http][:sandbox], do: options[:http][:sandbox], else: @sandbox_enabled

    headers = build_headers(options)

    if sandbox? and !sandbox_disabled?() do
      sandbox_delete_response(url, headers, options)
    else
      if function_exported?(http_adapter, :delete, 3) do
        http_adapter.delete(url, headers, options)
      else
        http_adapter.request(:delete, url, nil, headers, options)
      end
      |> handle_response()
    end
  end

  def post(url, body \\ nil, options \\ []) do
    http_adapter =
      if options[:http][:adapter], do: options[:http][:adapter], else: @default_http_adapter

    sandbox? =
      if options[:http][:sandbox], do: options[:http][:sandbox], else: @sandbox_enabled

    headers = build_headers(options)

    if sandbox? and !sandbox_disabled?() do
      sandbox_post_response(url, body, headers, options)
    else
      if function_exported?(http_adapter, :post, 3) do
        http_adapter.post(url, body, headers, options)
      else
        http_adapter.request(:post, url, body, headers, options)
      end
      |> handle_response()
    end
  end

  def put(url, body \\ nil, options \\ []) do
    http_adapter =
      if options[:http][:adapter], do: options[:http][:adapter], else: @default_http_adapter

    sandbox? =
      if options[:http][:sandbox], do: options[:http][:sandbox], else: @sandbox_enabled

    headers = build_headers(options)

    if sandbox? and !sandbox_disabled?() do
      sandbox_put_response(url, body, headers, options)
    else
      if function_exported?(http_adapter, :put, 3) do
        http_adapter.put(url, body, headers, options)
      else
        http_adapter.request(:put, url, body, headers, options)
      end
      |> handle_response()
    end
  end

  defp build_headers(_options) do
    []
  end

  defp handle_response({:ok, %{body: _, status: _, headers: _}} = resp) do
    resp
  end

  defp handle_response({:ok, {body, %{status: status, headers: headers}}}) do
    {:ok, %{body: body, status: status, headers: headers}}
  end

  defp handle_response({:error, _} = e) do
    e
  end

  if Mix.env() === :test do
    defdelegate sandbox_head_response(url, headers, options),
      to: AWS.Support.HTTPSandbox,
      as: :head_response

    defdelegate sandbox_get_response(url, headers, options),
      to: AWS.Support.HTTPSandbox,
      as: :get_response

    defdelegate sandbox_delete_response(url, headers, options),
      to: AWS.Support.HTTPSandbox,
      as: :delete_response

    defdelegate sandbox_post_response(url, body, headers, options),
      to: AWS.Support.HTTPSandbox,
      as: :post_response

    defdelegate sandbox_put_response(url, body, headers, options),
      to: AWS.Support.HTTPSandbox,
      as: :put_response

    defdelegate sandbox_disabled?, to: AWS.Support.HTTPSandbox
  else
    defp sandbox_head_response(url, _, _) do
      raise """
      Cannot use HTTPSandbox outside of test.

      Action: HEAD
      URL requested: #{inspect(url)}
      """
    end

    defp sandbox_get_response(url, _, _) do
      raise """
      Cannot use HTTPSandbox outside of test.

      Action: GET
      URL requested: #{inspect(url)}
      """
    end

    defp sandbox_delete_response(url, _, _) do
      raise """
      Cannot use HTTPSandbox outside of test.

      Action: DELETE
      URL requested: #{inspect(url)}
      """
    end

    defp sandbox_post_response(url, _, _, _) do
      raise """
      Cannot use HTTPSandbox outside of test.

      Action: PUT
      URL requested: #{inspect(url)}
      """
    end

    defp sandbox_put_response(url, _, _, _) do
      raise """
      Cannot use HTTPSandbox outside of test.

      Action: PUT
      URL requested: #{inspect(url)}
      """
    end

    defp sandbox_disabled?, do: true
  end
end
