defmodule AWS.SSM do
  @moduledoc """
  `AWS.SSM` provides an API for AWS Systems Manager.

  This API calls the AWS Systems Manager JSON 1.1 API directly over HTTP
  using `Finch` as the HTTP client, Erlang's built-in `:json` for
  encoding/decoding (OTP 27+ required), and a hand-rolled SigV4 signer.
  It provides consistent error handling, response deserialization, and
  sandbox support.

  The initial surface covers Parameter Store. See the botocore service
  model for the authoritative API reference:
  <https://github.com/boto/botocore/blob/master/botocore/data/ssm/2014-11-06/service-2.json>

  SSM uses PascalCase keys on the wire (e.g. `Name`, `WithDecryption`,
  `Parameters`). Response bodies are deserialized to snake_case atom-keyed
  maps via `ExUtils.Serializer`.

  ## Shared Options

  Credentials and region are flat top-level opts on every call (ex_aws shape).
  Each accepts a literal, a source tuple, or a list of sources (first
  non-nil wins):

    - `:access_key_id`, `:secret_access_key`, `:security_token`, `:region` -
      Sources: literal binary, `{:system, "ENV"}`, `:instance_role`,
      `:ecs_task_role`, `{:awscli, profile}` / `{:awscli, profile, ttl}`,
      a module, or a list of any of these. Map-returning sources merge
      into the outer config. `{:awscli, _}` is not in the default chain —
      callers opt in explicitly.

  The following options are also available:

    - `:ssm` - A keyword list of Systems Manager endpoint overrides.
      Supported keys: `:scheme`, `:host`, `:port`. Credentials are not
      read from this sub-list; use the top-level keys above.

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

      AWS.SSM.Sandbox.start_link()

  ### Usage

      setup do
        AWS.SSM.Sandbox.set_get_parameter_responses([
          {"/app/db/host",
           fn -> {:ok, %{parameter: %{name: "/app/db/host", value: "db.internal"}}} end}
        ])
      end

      test "reads a parameter" do
        assert {:ok, %{parameter: %{value: "db.internal"}}} =
                 AWS.SSM.get_parameter("/app/db/host",
                   sandbox: [enabled: true, mode: :inline]
                 )
      end
  """

  alias AWS.{Client, Config}
  alias AWS.SSM.Operation
  alias ExUtils.Serializer

  @service "ssm"
  @content_type "application/x-amz-json-1.1"
  @target_prefix "AmazonSSM"

  @override_keys [:headers, :body, :http, :url]

  # ---------------------------------------------------------------------------
  # Parameter Store
  # ---------------------------------------------------------------------------

  @doc """
  Returns information about a single parameter from Parameter Store.

  ## Arguments

    * `name` - The fully qualified parameter name (e.g. `"/app/db/host"`),
      or `"name:version"` / `"name:label"` to pin a specific version or label.
    * `opts` - Options including `:with_decryption`, plus shared options.
  """
  @spec get_parameter(name :: String.t(), opts :: keyword()) ::
          {:ok, %{parameter: map()}} | {:error, term()}
  def get_parameter(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_parameter_response(name, opts)
    else
      do_get_parameter(name, opts)
    end
  end

  defp do_get_parameter(name, opts) do
    data =
      %{"Name" => name}
      |> maybe_put("WithDecryption", opts[:with_decryption])

    perform("GetParameter", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Returns information about multiple parameters in a single call.

  ## Arguments

    * `names` - A list of 1-10 parameter names.
    * `opts` - Options including `:with_decryption`, plus shared options.
  """
  @spec get_parameters(names :: [String.t()], opts :: keyword()) ::
          {:ok, %{parameters: [map()], invalid_parameters: [String.t()]}} | {:error, term()}
  def get_parameters(names, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_parameters_response(names, opts)
    else
      do_get_parameters(names, opts)
    end
  end

  defp do_get_parameters(names, opts) do
    data =
      %{"Names" => names}
      |> maybe_put("WithDecryption", opts[:with_decryption])

    perform("GetParameters", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Returns parameters in a hierarchy by path prefix.

  ## Arguments

    * `path` - The hierarchy prefix (e.g. `"/app/"`). Must begin with `/`.
    * `opts` - Options:
      * `:recursive` - Boolean; descend into sub-paths.
      * `:with_decryption` - Boolean; return decrypted SecureString values.
      * `:parameter_filters` - List of filter maps with PascalCase keys
        (e.g. `[%{"Key" => "Type", "Values" => ["String"]}]`).
      * `:max_results` - Integer page size.
      * `:next_token` - Pagination token from a prior response.
  """
  @spec get_parameters_by_path(path :: String.t(), opts :: keyword()) ::
          {:ok, %{parameters: [map()], next_token: String.t() | nil}} | {:error, term()}
  def get_parameters_by_path(path, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_get_parameters_by_path_response(path, opts)
    else
      do_get_parameters_by_path(path, opts)
    end
  end

  defp do_get_parameters_by_path(path, opts) do
    data =
      %{"Path" => path}
      |> maybe_put("Recursive", opts[:recursive])
      |> maybe_put("WithDecryption", opts[:with_decryption])
      |> maybe_put("ParameterFilters", opts[:parameter_filters])
      |> maybe_put("MaxResults", opts[:max_results])
      |> maybe_put("NextToken", opts[:next_token])

    perform("GetParametersByPath", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Creates or updates a parameter in Parameter Store.

  ## Arguments

    * `name` - The fully qualified parameter name (e.g. `"/app/db/host"`).
    * `value` - The parameter value.
    * `opts` - Options:
      * `:type` - `"String"` (default if not provided to AWS),
        `"StringList"`, or `"SecureString"`. Required on first write.
      * `:description` - String description.
      * `:key_id` - KMS key ARN or alias (required for SecureString unless
        the AWS-managed `alias/aws/ssm` is used).
      * `:overwrite` - Boolean; allow updating an existing parameter.
      * `:allowed_pattern` - Regex pattern the value must match.
      * `:tags` - List of `%{"Key" => k, "Value" => v}` maps.
      * `:tier` - `"Standard"`, `"Advanced"`, or `"Intelligent-Tiering"`.
      * `:policies` - JSON-encoded policy string.
      * `:data_type` - `"text"` or `"aws:ec2:image"` for AMI parameters.
  """
  @spec put_parameter(name :: String.t(), value :: String.t(), opts :: keyword()) ::
          {:ok, %{version: integer(), tier: String.t()}} | {:error, term()}
  def put_parameter(name, value, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_put_parameter_response(name, value, opts)
    else
      do_put_parameter(name, value, opts)
    end
  end

  defp do_put_parameter(name, value, opts) do
    data =
      %{"Name" => name, "Value" => value}
      |> maybe_put("Type", opts[:type])
      |> maybe_put("Description", opts[:description])
      |> maybe_put("KeyId", opts[:key_id])
      |> maybe_put("Overwrite", opts[:overwrite])
      |> maybe_put("AllowedPattern", opts[:allowed_pattern])
      |> maybe_put("Tags", opts[:tags])
      |> maybe_put("Tier", opts[:tier])
      |> maybe_put("Policies", opts[:policies])
      |> maybe_put("DataType", opts[:data_type])

    perform("PutParameter", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Deletes a single parameter.
  """
  @spec delete_parameter(name :: String.t(), opts :: keyword()) ::
          {:ok, map()} | {:error, term()}
  def delete_parameter(name, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_parameter_response(name, opts)
    else
      do_delete_parameter(name, opts)
    end
  end

  defp do_delete_parameter(name, opts) do
    perform("DeleteParameter", %{"Name" => name}, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Deletes a batch of parameters (1-10 names per call).
  """
  @spec delete_parameters(names :: [String.t()], opts :: keyword()) ::
          {:ok, %{deleted_parameters: [String.t()], invalid_parameters: [String.t()]}}
          | {:error, term()}
  def delete_parameters(names, opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_delete_parameters_response(names, opts)
    else
      do_delete_parameters(names, opts)
    end
  end

  defp do_delete_parameters(names, opts) do
    perform("DeleteParameters", %{"Names" => names}, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  @doc """
  Lists parameter metadata (no values). Useful for browsing or auditing.

  ## Options

    * `:filters` - Legacy `ParametersFilter` list of `%{"Key" => k, "Values" => vs}`.
    * `:parameter_filters` - Preferred `ParameterStringFilter` list.
    * `:max_results` - Integer page size.
    * `:next_token` - Pagination token.
    * `:shared` - Boolean; include parameters shared from other accounts.
  """
  @spec describe_parameters(opts :: keyword()) ::
          {:ok, %{parameters: [map()], next_token: String.t() | nil}} | {:error, term()}
  def describe_parameters(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_parameters_response(opts)
    else
      do_describe_parameters(opts)
    end
  end

  defp do_describe_parameters(opts) do
    data =
      %{}
      |> maybe_put("Filters", opts[:filters])
      |> maybe_put("ParameterFilters", opts[:parameter_filters])
      |> maybe_put("MaxResults", opts[:max_results])
      |> maybe_put("NextToken", opts[:next_token])
      |> maybe_put("Shared", opts[:shared])

    perform("DescribeParameters", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  # ---------------------------------------------------------------------------
  # Managed instances
  # ---------------------------------------------------------------------------

  @doc """
  Describes one or more of your managed nodes, including information about
  operating system platform, SSM Agent version, association status, and IP
  address. AWS returns one entry per managed node.

  ## Options

    * `:instance_information_filter_list` - Legacy
      `InstanceInformationFilterList` of `%{"key" => k, "valueSet" => vs}`.
    * `:filters` - Preferred `InstanceInformationStringFilterList` of
      `%{"Key" => k, "Values" => vs}`.
    * `:max_results` - Integer page size (5-50).
    * `:next_token` - Pagination token from a prior response.
  """
  @spec describe_instance_information(opts :: keyword()) ::
          {:ok, %{instance_information_list: [map()], next_token: String.t() | nil}}
          | {:error, term()}
  def describe_instance_information(opts \\ []) do
    if inline_sandbox?(opts) do
      sandbox_describe_instance_information_response(opts)
    else
      do_describe_instance_information(opts)
    end
  end

  defp do_describe_instance_information(opts) do
    data =
      %{}
      |> maybe_put("InstanceInformationFilterList", opts[:instance_information_filter_list])
      |> maybe_put("Filters", opts[:filters])
      |> maybe_put("MaxResults", opts[:max_results])
      |> maybe_put("NextToken", opts[:next_token])

    perform("DescribeInstanceInformation", data, opts)
    |> deserialize_response(opts, fn body ->
      Serializer.deserialize(body, deserialize_opts(opts))
    end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @doc false
  def build_operation(action, data, opts) do
    with {:ok, config} <-
           Client.resolve_config(:ssm, opts, &"ssm.#{&1}.amazonaws.com") do
      op = %Operation{
        method: :post,
        url: Client.simple_url(config),
        headers: [
          {"content-type", @content_type},
          {"x-amz-target", "#{@target_prefix}.#{action}"}
        ],
        body: encode_body(data),
        service: @service,
        region: config.region,
        access_key_id: config.access_key_id,
        secret_access_key: config.secret_access_key,
        security_token: config.security_token,
        http: Keyword.get(opts, :http, [])
      }

      {:ok, apply_overrides(op, opts[:ssm] || [])}
    end
  end

  defp perform(action, data, opts) do
    with {:ok, op} <- build_operation(action, data, opts) do
      op
      |> Client.execute()
      |> decode_response()
    end
  end

  defp apply_overrides(op, overrides) do
    Enum.reduce(@override_keys, op, fn key, acc ->
      case Keyword.fetch(overrides, key) do
        {:ok, value} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  defp encode_body(data) when map_size(data) === 0, do: "{}"
  defp encode_body(data), do: data |> :json.encode() |> IO.iodata_to_binary()

  defp decode_response({:ok, %{body: body}}), do: {:ok, decode_body(body)}

  defp decode_response({:error, {:http_error, status, body}}),
    do: {:error, {:http_error, status, decode_body(body)}}

  defp decode_response({:error, _reason} = err), do: err

  defp decode_body(""), do: %{}

  defp decode_body(binary) when is_binary(binary) do
    :json.decode(binary)
  rescue
    _ -> binary
  end

  # AWS owns the response-body namespace and adds new fields over time.
  # `Serializer.deserialize/2`'s default is `to_existing_atom: true, strict: true`,
  # which crashes on any field whose snake-cased atom hasn't been referenced
  # elsewhere in the project. Bodies must round-trip without crashing, so
  # atom-safety is relaxed here by default. Callers can still override any of
  # these options by passing their own `opts` -- caller-supplied keys win the merge.
  @deserialize_defaults [to_existing_atom: false, strict: false]

  defp deserialize_opts(opts), do: Keyword.merge(@deserialize_defaults, opts)

  defp deserialize_response({:ok, response}, _opts, func) do
    case func.(response) do
      {:error, _} = error -> error
      {:ok, _} = ok -> ok
      result -> {:ok, result}
    end
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, _opts, _func)
       when status_code in 400..499 do
    {:error, ErrorMessage.not_found("resource not found.", %{response: response})}
  end

  defp deserialize_response({:error, {:http_error, status_code, response}}, _opts, _func)
       when status_code >= 500 do
    {:error,
     ErrorMessage.service_unavailable("service temporarily unavailable", %{response: response})}
  end

  defp deserialize_response({:error, reason}, _opts, _func) do
    {:error, ErrorMessage.internal_server_error("internal server error", %{reason: reason})}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, false), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # ---------------------------------------------------------------------------
  # Sandbox delegation
  # ---------------------------------------------------------------------------

  defp inline_sandbox?(opts) do
    sandbox_opts = opts[:sandbox] || []
    cfg = Config.sandbox()
    enabled = Keyword.get(sandbox_opts, :enabled, cfg[:enabled])
    mode = Keyword.get(sandbox_opts, :mode, cfg[:mode])

    enabled and mode === :inline and not sandbox_disabled?()
  end

  if Code.ensure_loaded?(SandboxRegistry) do
    @doc false
    defdelegate sandbox_disabled?, to: AWS.SSM.Sandbox

    @doc false
    defdelegate sandbox_get_parameter_response(name, opts),
      to: AWS.SSM.Sandbox,
      as: :get_parameter_response

    @doc false
    defdelegate sandbox_get_parameters_response(names, opts),
      to: AWS.SSM.Sandbox,
      as: :get_parameters_response

    @doc false
    defdelegate sandbox_get_parameters_by_path_response(path, opts),
      to: AWS.SSM.Sandbox,
      as: :get_parameters_by_path_response

    @doc false
    defdelegate sandbox_put_parameter_response(name, value, opts),
      to: AWS.SSM.Sandbox,
      as: :put_parameter_response

    @doc false
    defdelegate sandbox_delete_parameter_response(name, opts),
      to: AWS.SSM.Sandbox,
      as: :delete_parameter_response

    @doc false
    defdelegate sandbox_delete_parameters_response(names, opts),
      to: AWS.SSM.Sandbox,
      as: :delete_parameters_response

    @doc false
    defdelegate sandbox_describe_parameters_response(opts),
      to: AWS.SSM.Sandbox,
      as: :describe_parameters_response

    @doc false
    defdelegate sandbox_describe_instance_information_response(opts),
      to: AWS.SSM.Sandbox,
      as: :describe_instance_information_response
  else
    defp sandbox_disabled?, do: true

    defp sandbox_get_parameter_response(_, _), do: raise("sandbox not available")
    defp sandbox_get_parameters_response(_, _), do: raise("sandbox not available")
    defp sandbox_get_parameters_by_path_response(_, _), do: raise("sandbox not available")
    defp sandbox_put_parameter_response(_, _, _), do: raise("sandbox not available")
    defp sandbox_delete_parameter_response(_, _), do: raise("sandbox not available")
    defp sandbox_delete_parameters_response(_, _), do: raise("sandbox not available")
    defp sandbox_describe_parameters_response(_), do: raise("sandbox not available")
    defp sandbox_describe_instance_information_response(_), do: raise("sandbox not available")
  end
end
