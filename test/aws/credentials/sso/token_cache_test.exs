defmodule AWS.Credentials.SSO.TokenCacheTest do
  use ExUnit.Case, async: true

  alias AWS.Credentials.SSO.TokenCache
  alias AWS.CredentialsFixtures

  @tag :tmp_dir
  test "path/2 hashes the key with sha1-hex", %{tmp_dir: tmp} do
    home = CredentialsFixtures.build_home(tmp)
    path = TokenCache.path("main", home_dir: home)

    expected_hash = :sha |> :crypto.hash("main") |> Base.encode16(case: :lower)
    assert path === Path.join(home, ".aws/sso/cache/#{expected_hash}.json")
  end

  @tag :tmp_dir
  test "read/2 returns {:ok, contents} for a live cache", %{tmp_dir: tmp} do
    home = CredentialsFixtures.build_home(tmp)

    CredentialsFixtures.write_sso_cache(home, "main", %{
      "accessToken" => "abc",
      "expiresAt" => "2099-01-01T00:00:00Z"
    })

    assert {:ok, %{"accessToken" => "abc"}} = TokenCache.read("main", home_dir: home)
  end

  @tag :tmp_dir
  test "read/2 returns {:error, :enoent} when the file is missing", %{tmp_dir: tmp} do
    home = CredentialsFixtures.build_home(tmp)
    assert {:error, :enoent} = TokenCache.read("absent", home_dir: home)
  end

  @tag :tmp_dir
  test "write/3 atomically replaces the cache file with 0600 perms", %{tmp_dir: tmp} do
    home = CredentialsFixtures.build_home(tmp)
    assert :ok = TokenCache.write("main", %{"accessToken" => "v1"}, home_dir: home)

    path = TokenCache.path("main", home_dir: home)
    stat = File.stat!(path)
    assert Bitwise.band(stat.mode, 0o777) === 0o600

    assert {:ok, %{"accessToken" => "v1"}} = TokenCache.read("main", home_dir: home)

    assert :ok = TokenCache.write("main", %{"accessToken" => "v2"}, home_dir: home)
    assert {:ok, %{"accessToken" => "v2"}} = TokenCache.read("main", home_dir: home)
  end
end
