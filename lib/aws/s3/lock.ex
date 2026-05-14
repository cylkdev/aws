defmodule AWS.S3.Lock do
  @moduledoc """
  Helpers for the S3-native lockfile pattern used by `AWS.S3.acquire_lock/3`,
  `AWS.S3.release_lock/3`, and `AWS.S3.with_lock/4`.

  This module owns the lock-domain concerns (body construction, ID generation,
  ID verification) that are not specific to the S3 wire protocol. The public
  S3 functions compose these helpers with `put_new_object`, `get_object`, and
  `delete_object`.

  Lock bodies default to a JSON document shaped to match Terraform's lock-info
  document (`"ID"`, `"Operation"`, `"Info"`, `"Who"`, `"Version"`, `"Created"`,
  `"Path"`), so a lockfile written by this library can be observed or released
  by Terraform's S3 backend (and vice versa) when `use_lockfile = true`.
  """

  @opt_keys [:lock_id, :operation, :info, :who, :version, :path, :body]

  @doc """
  Splits caller opts into a `{lock_id, body, remaining_opts}` triple.

  Lock-related keys (`:lock_id`, `:operation`, `:info`, `:who`, `:version`,
  `:path`, `:body`) are consumed; everything else (credentials, sandbox,
  region, headers, ...) is returned untouched in `remaining_opts` so it can
  be passed through to the underlying S3 call.
  """
  @spec build(bucket :: binary(), key :: binary(), opts :: keyword()) ::
          {lock_id :: binary(), body :: binary(), remaining_opts :: keyword()}
  def build(bucket, key, opts) do
    {lock_opts, remaining_opts} = Keyword.split(opts, @opt_keys)
    lock_id = Keyword.get(lock_opts, :lock_id) || generate_id()

    body =
      case Keyword.get(lock_opts, :body) do
        nil -> default_body(bucket, key, lock_id, lock_opts)
        custom -> custom
      end

    {lock_id, body, remaining_opts}
  end

  @doc """
  Generates a 32-character lowercase hex lock ID from 16 bytes of CSPRNG
  output.
  """
  @spec generate_id() :: binary()
  def generate_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies that `body` belongs to a lock with `expected_id`.

  Tries to JSON-decode `body` and compare its `"ID"` field; falls back to a
  substring check so custom (non-JSON) bodies still verify when they embed
  the lock ID. Returns `:ok` on match, or `{:error, %ErrorMessage{}}` on
  mismatch.
  """
  @spec verify_id(
          body :: binary(),
          expected_id :: binary(),
          bucket :: binary(),
          key :: binary()
        ) :: :ok | {:error, ErrorMessage.t()}
  def verify_id(body, expected_id, bucket, key) do
    actual_id =
      case Jason.decode(body) do
        {:ok, %{"ID" => id}} -> id
        _ -> nil
      end

    if actual_id == expected_id or String.contains?(body, expected_id) do
      :ok
    else
      {:error,
       ErrorMessage.conflict(
         "lock id does not match",
         %{bucket: bucket, key: key, expected: expected_id, actual: actual_id}
       )}
    end
  end

  defp default_body(bucket, key, lock_id, lock_opts) do
    Jason.encode!(%{
      "ID" => lock_id,
      "Operation" => Keyword.get(lock_opts, :operation, ""),
      "Info" => Keyword.get(lock_opts, :info, ""),
      "Who" => Keyword.get(lock_opts, :who) || default_who(),
      "Version" => Keyword.get(lock_opts, :version, ""),
      "Created" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "Path" => Keyword.get(lock_opts, :path) || "#{bucket}/#{key}"
    })
  end

  defp default_who do
    user = System.get_env("USER") || System.get_env("USERNAME") || "unknown"
    {:ok, host} = :inet.gethostname()
    "#{user}@#{host}"
  end
end
