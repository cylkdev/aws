if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.Sandbox do
    @moduledoc """
    Process-scoped registry of stub functions, shared by every
    `AwsSdk.<Service>.Sandbox` module.

    A test registers functions against its own PID; the service's sandbox
    module looks one up and applies it in place of an HTTP call. Nothing here
    is specific to AWS — it stores funs keyed by the function they stand in
    for and a lookup key.

    Each service's sandbox module holds its registry name in `@registry` and
    writes one pair of functions per operation:

        def create_user_response(name, opts) do
          binding = [name: name, opts: opts]

          Sandbox.apply(@registry, __MODULE__, :create_user, name, binding)
        end

        def set_create_user_responses(entries) do
          Sandbox.register(@registry, __MODULE__, :create_user, entries)
        end

    ## Convention

    Sandbox modules name their registration function
    `set_<function>_responses/1`. This module relies on that when building the
    setup example shown in error messages. A module that names its setter
    otherwise still works, but its errors will point at a function that does
    not exist.
    """

    @state "state"
    @disabled "disabled"
    @sleep 10
    @keys :unique

    @typedoc """
    Selects which registered stub a call resolves to.

    A binary names one call. `:*` applies to every call of that function.
    """
    @type key :: String.t() | :*

    @doc false
    def start_link(registry), do: Registry.start_link(keys: @keys, name: registry)

    @doc false
    def disable(registry, module) do
      with {:error, :registry_not_started} <-
             SandboxRegistry.register(registry, @disabled, %{}, @keys) do
        raise_not_started!(module)
      end
    end

    @doc false
    def disabled?(registry, module) do
      case SandboxRegistry.lookup(registry, @disabled) do
        {:ok, _} -> true
        {:error, :registry_not_started} -> raise_not_started!(module)
        {:error, :pid_not_registered} -> false
      end
    end

    @doc """
    Looks up the stub registered for `function` and applies it.

    This is the entire body of a sandbox operation: resolve the function the
    calling process registered, then call it with the operation's inputs.

    ## Arguments

      * `registry` — the service's registry name, held as `@registry` in each
        `AwsSdk.<Service>.Sandbox` (e.g. `:aws_iam_sandbox`).
      * `module` — the calling sandbox module. Diagnostic only: each service
        owns its own registry, so the registry key is `{function, key}` and
        `module` never participates in lookup. It exists to build the error
        message.
      * `function` — the operation as an atom (`:create_log_stream`). Half of
        the registry key; a stub registered under another function never
        matches.
      * `key` — the other half. A binary names one call, letting a test
        register a different result per resource; `:*` applies to every call
        of `function`. `nil` is not valid and fails the guard.
      * `binding` — the operation's parameters as a keyword list in
        declaration order, `opts` last. The names build the `fn` shapes shown
        in error messages; the values are what the stub is applied to. Write
        this list out by hand — `Kernel.binding/0` sorts alphabetically rather
        than by declaration order and would apply the wrong values.

    ## Lookup

    By `{function, key}`, in three ordered steps:

      1. **exact** — a binary key equal to `key`
      2. **pattern** — a `Regex` key registered for the same `function` whose
         pattern matches `key`. Skipped unless `key` is a binary, so
         `Regex.match?/2` is never handed an atom.
      3. **wildcard** — a stub registered under `:*`

    If several patterns match, which one wins is unspecified — register
    non-overlapping patterns. Stubs are held in a map, and map iteration is
    neither insertion nor sorted order.

    ## Return value

    Whatever the stub returns, unaltered — this module never inspects or wraps
    it. Tests register the service's own shapes:

        {:ok, %{log_streams: [], next_token: nil}}
        {:error, ErrorMessage.not_found("resource not found.", %{status: 404})}

    The stub is applied at its own arity, so a test writes only the parameters
    it cares about. Arity `0` is called with no arguments; any arity up to
    `length(binding)` receives that many leading values.

    ## Raises

      * the registry was never started for `module` — the message points at
        `test_helper.exs`
      * the calling process registered no stubs at all
      * stubs exist for this process but none match `{function, key}` — the
        message lists what was registered
      * a registered value is not a function
      * a registered function's arity exceeds `length(binding)`

    ## Examples

        # In AwsSdk.Logs.Sandbox.
        def create_log_stream_response(group, stream, opts) do
          binding = [group: group, stream: stream, opts: opts]

          Sandbox.apply(@registry, __MODULE__, :create_log_stream, group, binding)
        end

        # A test registers against that key:
        AwsSdk.Logs.Sandbox.set_create_log_stream_responses([
          {"my-group", fn -> {:ok, %{}} end}
        ])

        AwsSdk.Logs.create_log_stream("my-group", "stream-a", sandbox: [enabled: true])
        #=> {:ok, %{}}

        # A different group does not match, so the call raises rather than
        # returning a response meant for another test.
        AwsSdk.Logs.create_log_stream("other", "stream-a", sandbox: [enabled: true])
        #=> ** (RuntimeError) Function not found.

        # A higher-arity stub receives the values in declaration order.
        AwsSdk.Logs.Sandbox.set_create_log_stream_responses([
          {~r/^prod-/, fn group, stream, opts -> {:ok, %{group: group, stream: stream}} end}
        ])

        AwsSdk.Logs.create_log_stream("prod-api", "stream-a", sandbox: [enabled: true])
        #=> {:ok, %{group: "prod-api", stream: "stream-a"}}

    An operation with no inputs passes `:*`:

        def list_users_response(opts) do
          binding = [opts: opts]

          Sandbox.apply(@registry, __MODULE__, :list_users, :*, binding)
        end
    """
    @spec apply(atom, module, atom, key, keyword) :: term
    def apply(registry, module, function, key, binding)
        when is_binary(key) or key === :* do
      names = Keyword.keys(binding)
      args = Keyword.values(binding)
      examples = examples(names)
      fun = fetch!(registry, module, function, key, examples)
      arity = :erlang.fun_info(fun)[:arity]

      case arity do
        0 -> fun.()
        n when n <= length(args) -> Kernel.apply(fun, Enum.take(args, n))
        _ -> raise_unsupported_arity(fun, examples)
      end
    end

    @doc """
    Registers stub functions for `function` against the calling process.

    Each entry is a `{key, fun}` tuple, or a bare `fun` — shorthand for
    `{:*, fun}`, used by operations that take no inputs.

    `key` is an exact binary compared for equality, a `Regex` matched against
    the key the operation passes to `apply/5`, or `:*`.

    Registration is per-process and additive: registering a second function
    leaves the first in place; registering the same `{function, key}` twice
    replaces the earlier stub. Returns `:ok`, sleeping briefly so the
    registration is visible before the test proceeds. Raises if the registry
    was never started for `module`.

    ## Examples

        AwsSdk.IAM.Sandbox.set_get_user_responses([
          {"alice", fn -> {:ok, %{user: %{user_name: "alice"}}} end},
          {"bob", fn -> {:error, ErrorMessage.not_found("resource not found.")} end}
        ])

        AwsSdk.IAM.Sandbox.set_get_user_responses([
          {~r/^svc-/, fn name -> {:ok, %{user: %{user_name: name}}} end}
        ])

        # Applies to every call, whatever the key.
        AwsSdk.IAM.Sandbox.set_get_user_responses([
          {:*, fn name -> {:error, ErrorMessage.not_found("no such user", %{name: name})} end}
        ])

        # No inputs — the bare form.
        AwsSdk.IAM.Sandbox.set_list_users_responses([fn -> {:ok, %{users: []}} end])
    """
    @spec register(atom, module, atom, [{key | Regex.t(), function} | function]) :: :ok
    def register(registry, module, function, entries) do
      :ok =
        entries
        |> Enum.map(fn
          {_key, _fun} = entry -> entry
          fun when is_function(fun) -> {:*, fun}
        end)
        |> Map.new(fn {key, fun} -> {{function, key}, fun} end)
        |> then(&SandboxRegistry.register(registry, @state, &1, @keys))
        |> then(fn
          :ok -> :ok
          {:error, :registry_not_started} -> raise_not_started!(module)
        end)

      :ok = Process.sleep(@sleep)
    end

    # -------------------------------------------------------------------------
    # Deprecated primitives — retained until every sandbox module is migrated
    # to apply/5 and register/4, then deleted.
    # -------------------------------------------------------------------------

    @doc false
    def set_responses(registry, module, action, tuples) do
      register(registry, module, action, tuples)
    end

    @doc false
    def normalize_no_key(items) do
      Enum.map(items, fn
        {_key, _func} = tuple -> tuple
        func when is_function(func) -> {"*", func}
      end)
    end

    @doc false
    def find!(registry, module, action, name, doc_examples) do
      fetch!(registry, module, action, name, doc_examples)
    end

    @doc false
    def apply_func(func, args, doc_examples) do
      arity = :erlang.fun_info(func)[:arity]

      case arity do
        0 -> func.()
        n when n <= length(args) -> Kernel.apply(func, Enum.take(args, n))
        _ -> raise_unsupported_arity(func, doc_examples)
      end
    end

    @doc false
    def doc_examples(arg_names) do
      full = Enum.map_join(arg_names ++ [:opts], ", ", &to_string/1)

      case arg_names do
        [] -> ["fn -> ... end", "fn opts -> ... end"]
        [first | _] -> ["fn -> ... end", "fn #{first} -> ... end", "fn #{full} -> ... end"]
      end
    end

    # -------------------------------------------------------------------------
    # Lookup
    # -------------------------------------------------------------------------

    defp fetch!(registry, module, function, key, examples) do
      case SandboxRegistry.lookup(registry, @state) do
        {:ok, state} ->
          fetch_stub!(state, module, function, key, examples)

        {:error, :pid_not_registered} ->
          raise """
          No functions have been registered for #{inspect(self())}.

          Function: #{inspect(function)}
          Key: #{inspect(key)}

          Add one of the following patterns to your test setup:

          #{format_example(module, function, examples)}

          Replace `_response` with the value you want the sandbox to return.
          """

        {:error, :registry_not_started} ->
          raise_not_started!(module)
      end
    end

    defp fetch_stub!(state, module, function, key, examples) do
      exact = Map.get(state, {function, key})
      pattern = if is_binary(key), do: match_pattern(state, function, key)
      wildcard = Map.get(state, {function, :*})

      case exact || pattern || wildcard do
        fun when is_function(fun) ->
          fun

        nil ->
          registered =
            Enum.map_join(state, "\n", fn {registered_key, value} ->
              " #{inspect(registered_key)} => #{inspect(value)}"
            end)

          example = indent(format_example(module, function, examples), "  ")

          raise """
          Function not found.

            function: #{inspect(function)}
            key: #{inspect(key)}
            pid: #{inspect(self())}

          Found:

          #{registered}

          ---

          You need to register stubs for `#{inspect(function)}` calls.

          #{example}
          """

        other ->
          raise """
          Unrecognized input for #{inspect({function, key})} in #{inspect(self())}.

          Found value:

          #{inspect(other)}

          To fix this, update your test setup:

          #{format_example(module, function, examples)}
          """
      end
    end

    defp match_pattern(state, function, key) do
      Enum.find_value(state, fn
        {{^function, %Regex{} = regex}, fun} -> if Regex.match?(regex, key), do: fun
        _entry -> nil
      end)
    end

    # -------------------------------------------------------------------------
    # Error message construction
    # -------------------------------------------------------------------------

    defp examples(names) do
      first = List.first(names)
      full = Enum.map_join(names, ", ", &to_string/1)

      Enum.uniq(["fn -> ... end", "fn #{first} -> ... end", "fn #{full} -> ... end"])
    end

    defp indent(text, prefix) do
      text
      |> String.split("\n", trim: false)
      |> Enum.map_join("\n", &"#{prefix}#{&1}")
    end

    defp format_example(module, function, examples) do
      """
      alias #{inspect(module)}

      setup do
        #{inspect(module)}.set_#{function}_responses([
          #{Enum.map_join(examples, "\n    # or\n", &("    " <> &1))}
          # or
          {~r|pattern|, fn -> _response end}
        ])
      end
      """
    end

    defp raise_unsupported_arity(fun, examples) do
      raise """
      This function's signature is not supported: #{inspect(fun)}

      Please provide a function with one of the following arities (0-#{length(examples) - 1}):

      #{Enum.map_join(examples, "\n", &("    " <> &1))}
      """
    end

    defp raise_not_started!(module) do
      raise """
      Registry not started for #{inspect(module)}.

      To fix this, add the following line to your `test_helper.exs`:

          #{inspect(module)}.start_link()
      """
    end
  end
end
