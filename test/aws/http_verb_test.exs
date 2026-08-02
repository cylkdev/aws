defmodule AWS.HTTPVerbTest do
  @moduledoc """
  Drives the library the way a caller does -- `AWS.S3.get_object/3`,
  `AWS.STS.get_caller_identity/1` -- pointed at a real local HTTP server via
  the public `s3:`/`sts:` host overrides, and asserts on the method that
  server actually received.

  Req >= 0.7 infers POST from the presence of a request body, and an empty
  binary counts as present. Because `AWS.Client.execute/1` defaults
  `body = Map.get(op, :body, "")`, every bodyless call in the library was
  being promoted to POST. Against the Identity Center portal that surfaced
  to callers as
  `com.amazonaws.switchboard.portal#MethodNotAllowedException` (405).

  The server is a real Cowboy listener rather than a stubbed Req adapter, so
  the full path -- Req steps, Finch, socket -- stays under test. That also
  keeps the `finch: [name: ...]` option shape covered, which was the other
  Req 0.7 break.

  The SSO tests each use a distinct profile name because `AWS.AuthCache`
  memoizes resolved credentials per profile for 30s -- sharing a name would
  let one test serve the next from cache and skip the portal call entirely.
  """

  use ExUnit.Case, async: false

  @sts_body "<GetCallerIdentityResponse><GetCallerIdentityResult>" <>
              "<Arn>arn:aws:iam::1:user/x</Arn><UserId>AIDA</UserId><Account>1</Account>" <>
              "</GetCallerIdentityResult></GetCallerIdentityResponse>"

  @role_credentials ~s({"roleCredentials":{"accessKeyId":"AK","secretAccessKey":"SK",) <>
                      ~s("sessionToken":"ST","expiration":1800000000000}})

  test "AWS.S3.get_object/3 issues a GET" do
    ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(AWS.WireRecorderPlug, [test: self(), body: "hello"], ref: ref, port: 0)

    on_exit(fn -> Plug.Cowboy.shutdown(ref) end)

    assert {:ok, "hello"} =
             AWS.S3.get_object("my-bucket", "my-key",
               access_key_id: "AK",
               secret_access_key: "SK",
               region: "us-east-1",
               s3: [
                 scheme: "http",
                 host: "127.0.0.1",
                 port: :ranch.get_port(ref),
                 path_style: true
               ]
             )

    assert_receive {:request, "GET", "/my-bucket/my-key", _query}, 2_000
  end

  test "AWS.S3.head_object/3 issues a HEAD" do
    ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(
        AWS.WireRecorderPlug,
        [test: self(), resp_headers: [{"etag", "\"abc\""}]],
        ref: ref,
        port: 0
      )

    on_exit(fn -> Plug.Cowboy.shutdown(ref) end)

    assert {:ok, _} =
             AWS.S3.head_object("my-bucket", "my-key",
               access_key_id: "AK",
               secret_access_key: "SK",
               region: "us-east-1",
               s3: [
                 scheme: "http",
                 host: "127.0.0.1",
                 port: :ranch.get_port(ref),
                 path_style: true
               ]
             )

    assert_receive {:request, "HEAD", "/my-bucket/my-key", _query}, 2_000
  end

  test "AWS.S3.delete_object/3 issues a DELETE" do
    ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(AWS.WireRecorderPlug, [test: self(), status: 204], ref: ref, port: 0)

    on_exit(fn -> Plug.Cowboy.shutdown(ref) end)

    assert {:ok, _} =
             AWS.S3.delete_object("my-bucket", "my-key",
               access_key_id: "AK",
               secret_access_key: "SK",
               region: "us-east-1",
               s3: [
                 scheme: "http",
                 host: "127.0.0.1",
                 port: :ranch.get_port(ref),
                 path_style: true
               ]
             )

    assert_receive {:request, "DELETE", "/my-bucket/my-key", _query}, 2_000
  end

  test "AWS.S3.put_object/4 issues a PUT" do
    ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(
        AWS.WireRecorderPlug,
        [test: self(), resp_headers: [{"etag", "\"abc\""}]],
        ref: ref,
        port: 0
      )

    on_exit(fn -> Plug.Cowboy.shutdown(ref) end)

    assert {:ok, _} =
             AWS.S3.put_object("my-bucket", "my-key", "payload",
               access_key_id: "AK",
               secret_access_key: "SK",
               region: "us-east-1",
               s3: [
                 scheme: "http",
                 host: "127.0.0.1",
                 port: :ranch.get_port(ref),
                 path_style: true
               ]
             )

    assert_receive {:request, "PUT", "/my-bucket/my-key", _query}, 2_000
  end

  test "AWS.STS.get_caller_identity/1 issues a POST" do
    ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(AWS.WireRecorderPlug, [test: self(), body: @sts_body], ref: ref, port: 0)

    on_exit(fn -> Plug.Cowboy.shutdown(ref) end)

    assert {:ok, %{account: "1"}} =
             AWS.STS.get_caller_identity(
               access_key_id: "AK",
               secret_access_key: "SK",
               region: "us-east-1",
               sts: [scheme: "http", host: "127.0.0.1", port: :ranch.get_port(ref)]
             )

    assert_receive {:request, "POST", "/", _query}, 2_000
  end

  test "a call on an SSO profile fetches role credentials with a GET, then calls the service" do
    suffix = System.unique_integer([:positive])
    profile = "wire#{suffix}"
    session = "wire-session-#{suffix}"

    home = Path.join(System.tmp_dir!(), "verb_sso_#{suffix}")
    File.mkdir_p!(Path.join(home, ".aws"))
    on_exit(fn -> File.rm_rf!(home) end)

    File.write!(Path.join(home, ".aws/config"), """
    [profile #{profile}]
    sso_session = #{session}
    sso_account_id = 111122223333
    sso_role_name = WireRole

    [sso-session #{session}]
    sso_start_url = https://example.awsapps.com/start
    sso_region = us-east-1
    """)

    :ok =
      AWS.Credentials.SSO.TokenCache.write(
        session,
        %{
          "accessToken" => "live-token",
          "expiresAt" =>
            DateTime.utc_now() |> DateTime.add(3_600, :second) |> DateTime.to_iso8601()
        },
        home_dir: home
      )

    portal_ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(
        AWS.WireRecorderPlug,
        [test: self(), tag: :portal, body: @role_credentials],
        ref: portal_ref,
        port: 0
      )

    on_exit(fn -> Plug.Cowboy.shutdown(portal_ref) end)

    sts_ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(
        AWS.WireRecorderPlug,
        [test: self(), tag: :sts, body: @sts_body],
        ref: sts_ref,
        port: 0
      )

    on_exit(fn -> Plug.Cowboy.shutdown(sts_ref) end)

    assert {:ok, %{account: "1"}} =
             AWS.STS.get_caller_identity(
               profile: profile,
               home_dir: home,
               region: "us-east-1",
               # A closed port for OIDC: the cached token is live, so any
               # refresh attempt would fail loudly instead of passing silently.
               endpoints: [
                 oidc: "http://127.0.0.1:1",
                 portal: "http://127.0.0.1:#{:ranch.get_port(portal_ref)}"
               ],
               sts: [scheme: "http", host: "127.0.0.1", port: :ranch.get_port(sts_ref)]
             )

    # GetRoleCredentials must be a GET. A POST here is exactly what returned
    # `com.amazonaws.switchboard.portal#MethodNotAllowedException` (405).
    assert_receive {:portal, "GET", "/federation/credentials", query}, 2_000
    assert query == "account_id=111122223333&role_name=WireRole"

    assert_receive {:sts, "POST", "/", _query}, 2_000
  end

  test "a call on an SSO profile with a stale token refreshes over POST, then GETs the portal" do
    suffix = System.unique_integer([:positive])
    profile = "wire#{suffix}"
    session = "wire-session-#{suffix}"

    home = Path.join(System.tmp_dir!(), "verb_sso_#{suffix}")
    File.mkdir_p!(Path.join(home, ".aws"))
    on_exit(fn -> File.rm_rf!(home) end)

    File.write!(Path.join(home, ".aws/config"), """
    [profile #{profile}]
    sso_session = #{session}
    sso_account_id = 111122223333
    sso_role_name = WireRole

    [sso-session #{session}]
    sso_start_url = https://example.awsapps.com/start
    sso_region = us-east-1
    """)

    :ok =
      AWS.Credentials.SSO.TokenCache.write(
        session,
        %{
          "accessToken" => "stale-token",
          "expiresAt" =>
            DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.to_iso8601(),
          "refreshToken" => "refresh-me",
          "clientId" => "client-id",
          "clientSecret" => "client-secret",
          "registrationExpiresAt" =>
            DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.to_iso8601()
        },
        home_dir: home
      )

    oidc_ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(
        AWS.WireRecorderPlug,
        [test: self(), tag: :oidc, body: ~s({"accessToken":"fresh-token","expiresIn":3600})],
        ref: oidc_ref,
        port: 0
      )

    on_exit(fn -> Plug.Cowboy.shutdown(oidc_ref) end)

    portal_ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(
        AWS.WireRecorderPlug,
        [test: self(), tag: :portal, body: @role_credentials],
        ref: portal_ref,
        port: 0
      )

    on_exit(fn -> Plug.Cowboy.shutdown(portal_ref) end)

    sts_ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(
        AWS.WireRecorderPlug,
        [test: self(), tag: :sts, body: @sts_body],
        ref: sts_ref,
        port: 0
      )

    on_exit(fn -> Plug.Cowboy.shutdown(sts_ref) end)

    assert {:ok, %{account: "1"}} =
             AWS.STS.get_caller_identity(
               profile: profile,
               home_dir: home,
               region: "us-east-1",
               endpoints: [
                 oidc: "http://127.0.0.1:#{:ranch.get_port(oidc_ref)}",
                 portal: "http://127.0.0.1:#{:ranch.get_port(portal_ref)}"
               ],
               sts: [scheme: "http", host: "127.0.0.1", port: :ranch.get_port(sts_ref)]
             )

    # The OIDC refresh is a genuine POST; the portal call must stay a GET.
    assert_receive {:oidc, "POST", "/token", _query}, 2_000

    assert_receive {:portal, "GET", "/federation/credentials", query}, 2_000
    assert query == "account_id=111122223333&role_name=WireRole"

    assert_receive {:sts, "POST", "/", _query}, 2_000
  end

  test "a portal 401 surfaces to the caller as an error, and the attempt is still a GET" do
    suffix = System.unique_integer([:positive])
    profile = "wire#{suffix}"
    session = "wire-session-#{suffix}"

    home = Path.join(System.tmp_dir!(), "verb_sso_#{suffix}")
    File.mkdir_p!(Path.join(home, ".aws"))
    on_exit(fn -> File.rm_rf!(home) end)

    File.write!(Path.join(home, ".aws/config"), """
    [profile #{profile}]
    sso_session = #{session}
    sso_account_id = 111122223333
    sso_role_name = WireRole

    [sso-session #{session}]
    sso_start_url = https://example.awsapps.com/start
    sso_region = us-east-1
    """)

    :ok =
      AWS.Credentials.SSO.TokenCache.write(
        session,
        %{
          "accessToken" => "stale-token",
          "expiresAt" => DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.to_iso8601()
        },
        home_dir: home
      )

    portal_ref = make_ref()

    {:ok, _} =
      Plug.Cowboy.http(
        AWS.WireRecorderPlug,
        [
          test: self(),
          tag: :portal,
          status: 401,
          body: ~s({"message":"Session token not found or invalid"})
        ],
        ref: portal_ref,
        port: 0
      )

    on_exit(fn -> Plug.Cowboy.shutdown(portal_ref) end)

    assert {:error, %ErrorMessage{}} =
             AWS.STS.get_caller_identity(
               profile: profile,
               home_dir: home,
               region: "us-east-1",
               endpoints: [
                 oidc: "http://127.0.0.1:1",
                 portal: "http://127.0.0.1:#{:ranch.get_port(portal_ref)}"
               ],
               sts: [scheme: "http", host: "127.0.0.1", port: 1]
             )

    # Even the doomed attempt must be a GET -- a 405 here would mask the real
    # "your SSO token expired" signal behind a method error.
    assert_receive {:portal, "GET", "/federation/credentials", query}, 2_000
    assert query == "account_id=111122223333&role_name=WireRole"
  end
end
