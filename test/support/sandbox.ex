defmodule AWS.Support.HTTPSandbox do
  @moduledoc """
  For mocking out HTTP GET and POST requests in test.

  Stores a map of functions in a Registry under the PID of the test case when
  `set_get_responses/1` or `set_post_responses/1` are called.

  In test `AWS.HTTP` will default to using this sandbox to get that function
  and run it, returning the response instead of hitting an external API.
  """
  @sleep 10
  @state "state"
  @disabled "disabled_pids"
  @registry :http_sandbox
  @keys :unique

  @type action :: :get | :post
  @type url :: String.t()
  @type body :: map
  @type headers :: keyword
  @type options :: keyword

  @spec start_link :: {:error, any} | {:ok, pid}
  def start_link do
    Registry.start_link(keys: @keys, name: @registry)
  end

  @spec get_response(url, headers, options) :: any
  def get_response(url, headers, options) do
    func = find!(:get, url)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      3 -> func.(url, headers, options)
    end
  end

  @spec head_response(url, headers, options) :: any
  def head_response(url, headers, options) do
    func = find!(:head, url)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      3 -> func.(url, headers, options)
    end
  end

  @spec post_response(url, body, headers, options) :: any
  def post_response(url, body, headers, options) do
    func = find!(:post, url)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(body)
      3 -> func.(url, headers, options)
      4 -> func.(url, body, headers, options)
    end
  end

  @spec put_response(url, body, headers, options) :: any
  def put_response(url, body, headers, options) do
    func = find!(:put, url)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      1 -> func.(body)
      3 -> func.(url, headers, options)
      4 -> func.(url, body, headers, options)
    end
  end

  @spec delete_response(url, headers, options) :: any
  def delete_response(url, headers, options) do
    func = find!(:delete, url)

    case :erlang.fun_info(func)[:arity] do
      0 -> func.()
      3 -> func.(url, headers, options)
    end
  end

  @doc """
  Set sandbox responses in test. Call this function in your setup block with a list of tuples.

  The tuples have two elements:
  - The first element is either a string url or a regex that needs to match on the url
  - The second element is a 0 or 3 arity anonymous function. The arguments for the 3 arity
  are url, headers, options.


  ```elixir
  AWS.Support.HTTPSandbox.set_get_responses([{"http://google.com/", fn ->
    {:ok, {"I am a response", %AWS.HTTP.Response{status: 200}}}
  end}])

  # the url headers and opts can be pattern matched here to assert the correct request was sent.
  AWS.Support.HTTPSandbox.set_get_responses([
    {"http://google.com/", fn url, headers, opts ->
      {:ok, {"I am a response", %AWS.HTTP.Response{status: 200}}}
    end}])

  ```
  """
  @spec set_get_responses([{String.t(), fun}]) :: :ok
  def set_get_responses(tuples) do
    tuples
    |> Map.new(fn {url, func} -> {{:get, url}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> case do
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end

    Process.sleep(@sleep)
  end

  @doc "see set_get_responses/1"
  @spec set_head_responses([{String.t(), fun}]) :: :ok
  def set_head_responses(tuples) do
    tuples
    |> Map.new(fn {url, func} -> {{:head, url}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> case do
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end

    Process.sleep(@sleep)
  end

  @doc "see set_get_responses/1"
  @spec set_post_responses([{String.t(), fun}]) :: :ok
  def set_post_responses(tuples) do
    tuples
    |> Map.new(fn {url, func} -> {{:post, url}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> case do
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end

    Process.sleep(@sleep)
  end

  @doc "see set_get_responses/1"
  @spec set_put_responses([{String.t(), fun}]) :: :ok
  def set_put_responses(tuples) do
    tuples
    |> Map.new(fn {url, func} -> {{:put, url}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> case do
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end

    Process.sleep(@sleep)
  end

  @doc "see set_get_responses/1"
  @spec set_delete_responses([{String.t(), fun}]) :: :ok
  def set_delete_responses(tuples) do
    tuples
    |> Map.new(fn {url, func} -> {{:delete, url}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> case do
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end

    Process.sleep(@sleep)
  end

  @doc """
  Sets current pid to use actual caches rather than sandboxed

  import AWS.Support.HTTPSandbox, only: [disable_http_sandbox: 1]

  setup :disable_http_sandbox
  """
  @spec disable_http_sandbox(map) :: :ok
  def disable_http_sandbox(_context) do
    with {:error, :registry_not_started} <-
           SandboxRegistry.register(@registry, @disabled, %{}, @keys) do
      raise_not_started!()
    end
  end

  @doc "Check if sandbox for current pid was disabled by disable_http_sandbox/1"
  @spec sandbox_disabled? :: boolean
  def sandbox_disabled? do
    case SandboxRegistry.lookup(@registry, @disabled) do
      {:ok, _} -> true
      {:error, :registry_not_started} -> raise_not_started!()
      {:error, :pid_not_registered} -> false
    end
  end

  @doc """
  Finds out whether its PID or one of its ancestor's PIDs have been registered
  Returns response function or raises an error for developer
  """
  @spec find!(action, url) :: fun
  def find!(action, url) do
    case SandboxRegistry.lookup(@registry, @state) do
      {:ok, funcs} ->
        find_response!(funcs, action, url)

      {:error, :pid_not_registered} ->
        raise """
        No functions registered for #{inspect(self())}
        Action: #{inspect(action)}
        URL: #{inspect(url)}

        ======= Use: =======
        #{format_example(action, url)}
        === in your test ===
        """

      {:error, :registry_not_started} ->
        raise """
        Registry not started for #{inspect(__MODULE__)}.
        Please add the line:

        #{inspect(__MODULE__)}.start_link()

        to test_helper.exs for the current app.
        """
    end
  end

  defp find_response!(funcs, action, url) do
    key = {action, url}

    with funcs when is_map(funcs) <- Map.get(funcs, key, funcs),
         regexes <- Enum.filter(funcs, fn {{_, k}, _v} -> Regex.regex?(k) end),
         {_regex, func} when is_function(func) <-
           Enum.find(regexes, funcs, fn {{_, k}, _v} -> Regex.match?(k, url) end) do
      func
    else
      func when is_function(func) ->
        func

      functions when is_map(functions) ->
        functions_text =
          Enum.map_join(functions, "\n", fn {k, v} -> "#{inspect(k)}    =>    #{inspect(v)}" end)

        raise """
        Function not found for {action, url} in #{inspect(self())}
        Found:
        #{functions_text}

        ======= Use: =======
        #{format_example(action, url)}
        === in your test ===
        """

      other ->
        raise """
        Unrecognized input for {action, url} in #{inspect(self())}

        Did you use
        fn -> function() end
        in your set_get_responses/1 ?

        Found:
        #{inspect(other)}

        ======= Use: =======
        #{format_example(action, url)}
        === in your test ===
        """
    end
  end

  defp format_example(action, url) do
    """
    alias AWS.Support.HTTPSandbox

    setup do
      HTTPSandbox.set_#{action}_responses([
        {#{inspect(url)}, fn _url, _headers, _options -> _response end},
        # or
        {#{inspect(url)}, fn -> _response end}
        # or
        {~r|http://na1|, fn -> _response end}
      ])
    end
    """
  end

  defp raise_not_started! do
    raise """
    Registry not started for #{inspect(__MODULE__)}.
    Please add the line:

    #{inspect(__MODULE__)}.start_link()

    to test_helper.exs for the current app.
    """
  end
end
