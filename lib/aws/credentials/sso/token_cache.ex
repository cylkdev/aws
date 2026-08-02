defmodule AWS.Credentials.SSO.TokenCache do
  @moduledoc """
  Reads and writes `~/.aws/sso/cache/<sha1>.json` — the token cache
  populated by `aws sso login` and updated by OIDC refresh.

  The hash key is `sha1_hex(sso_session)` for modern profiles or
  `sha1_hex(sso_start_url)` for legacy ones. The AWS CLI uses the same
  algorithm.

  Writes are atomic: content is written to a temporary file in the same
  directory with `0600` permissions and then renamed into place, so a
  crashed refresh cannot leave a corrupt cache file.
  """

  require Logger

  @type cache :: %{
          optional(:accessToken) => String.t(),
          optional(:expiresAt) => String.t(),
          optional(:region) => String.t(),
          optional(:startUrl) => String.t(),
          optional(:refreshToken) => String.t(),
          optional(:clientId) => String.t(),
          optional(:clientSecret) => String.t(),
          optional(:registrationExpiresAt) => String.t()
        }

  @doc "Returns the cache file path for `key` inside `home`."
  @spec path(String.t(), keyword) :: Path.t()
  def path(key, opts \\ []) when is_binary(key) do
    hash = :sha |> :crypto.hash(key) |> Base.encode16(case: :lower)
    opts |> home() |> Path.join(".aws/sso/cache/#{hash}.json")
  end

  @doc """
  Reads and decodes the cache file for `key`.

  Returns `{:ok, map}`, `{:error, :enoent}` when the file is missing,
  or `{:error, {:invalid_json, reason}}` on a parse failure.
  """
  @spec read(String.t(), keyword) :: {:ok, map} | {:error, term}
  def read(key, opts \\ []) when is_binary(key) do
    with {:ok, contents} <- key |> path(opts) |> File.read() do
      decode_json(contents)
    end
  end

  @doc """
  Atomically writes `contents` into the cache file for `key`.

  The temp file is `<target>.tmp.<unique>`, chmodded to `0600`, then
  renamed onto the target path.
  """
  @spec write(String.t(), map, keyword) :: :ok | {:error, term}
  def write(key, contents, opts \\ []) when is_binary(key) and is_map(contents) do
    target = path(key, opts)
    tmp = "#{target}.tmp.#{System.unique_integer([:positive])}"
    body = contents |> :json.encode() |> IO.iodata_to_binary()

    # `mkdir_p` belongs in the `with` rather than its raising `!` variant:
    # the spec promises `{:error, term}`, and an unwritable ~/.aws is exactly
    # the failure callers need to handle.
    with :ok <- target |> Path.dirname() |> File.mkdir_p(),
         :ok <- File.write(tmp, body),
         :ok <- File.chmod(tmp, 0o600),
         :ok <- File.rename(tmp, target) do
      :ok
    else
      {:error, _} = err -> discard_temp(tmp, err)
    end
  end

  # The write already failed; this only removes the partial temp file. A
  # missing temp file is the normal case when `File.write/2` itself failed,
  # so it is not worth reporting -- anything else leaves a stray file behind.
  defp discard_temp(tmp, err) do
    case File.rm(tmp) do
      :ok ->
        err

      {:error, :enoent} ->
        err

      {:error, reason} ->
        Logger.warning(
          "[AWS.Credentials.SSO.TokenCache] left temp file #{tmp}: #{inspect(reason)}"
        )

        err
    end
  end

  defp decode_json(binary) do
    {:ok, :json.decode(binary)}
  rescue
    err -> {:error, {:invalid_json, Exception.message(err)}}
  end

  defp home(opts) do
    opts[:home_dir] || System.user_home!()
  end
end
