defmodule AWS.CredentialsFixtures do
  @moduledoc false

  @doc """
  Builds a fake `HOME` directory at `path` with the supplied
  `~/.aws/config` and `~/.aws/credentials` contents. Creates the
  `.aws/sso/cache` directory as well. Returns the home directory path.
  """
  def build_home(path, opts \\ []) do
    aws_dir = Path.join(path, ".aws")
    sso_cache_dir = Path.join(aws_dir, "sso/cache")
    File.mkdir_p!(sso_cache_dir)

    if config = opts[:config] do
      aws_dir |> Path.join("config") |> File.write!(config)
    end

    if credentials = opts[:credentials] do
      aws_dir |> Path.join("credentials") |> File.write!(credentials)
    end

    path
  end

  @doc """
  Writes a JSON file at `~/.aws/sso/cache/<key>.json` inside `home`.
  The SSO cache uses `sha1_hex(sso_session || sso_start_url)` as the
  file name. Tests can pass the raw key and let this helper hash it.
  """
  def write_sso_cache(home, key, contents) when is_map(contents) do
    home |> Path.join(".aws/sso/cache") |> File.mkdir_p!()
    hash = :sha |> :crypto.hash(key) |> Base.encode16(case: :lower)
    path = Path.join(home, ".aws/sso/cache/#{hash}.json")
    File.write!(path, contents |> :json.encode() |> IO.iodata_to_binary())
    path
  end
end
