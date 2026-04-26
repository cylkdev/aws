defmodule AWS.SignerTest do
  use ExUnit.Case

  alias AWS.Signer

  # Pinned timestamp so signatures are deterministic.
  @now ~U[2025-01-15 12:00:00Z]

  @creds %{
    access_key_id: "AKIDEXAMPLE",
    secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    region: "us-east-1",
    service: "s3",
    now: @now
  }

  describe "sign/5" do
    test "returns the canonical SigV4 header set" do
      headers =
        Signer.sign(
          :get,
          "https://examplebucket.s3.us-east-1.amazonaws.com/test.txt",
          [],
          "",
          @creds
        )

      names = Enum.map(headers, fn {k, _} -> k end)

      assert "host" in names
      assert "x-amz-date" in names
      assert "x-amz-content-sha256" in names
      assert "authorization" in names
    end

    test ":payload_hash override replaces hex_sha256(body) in the content-sha256 header" do
      creds = Map.put(@creds, :payload_hash, "UNSIGNED-PAYLOAD")

      headers =
        Signer.sign(
          :put,
          "https://examplebucket.s3.us-east-1.amazonaws.com/k",
          [],
          "ignored",
          creds
        )

      assert {"x-amz-content-sha256", "UNSIGNED-PAYLOAD"} in headers
    end

    test "security_token appears as x-amz-security-token header" do
      creds = Map.put(@creds, :token, "session-token")

      headers =
        Signer.sign(:get, "https://examplebucket.s3.us-east-1.amazonaws.com/k", [], "", creds)

      assert {"x-amz-security-token", "session-token"} in headers
    end

    test "signature is deterministic for pinned `now`" do
      h1 = Signer.sign(:get, "https://examplebucket.s3.us-east-1.amazonaws.com/k", [], "", @creds)
      h2 = Signer.sign(:get, "https://examplebucket.s3.us-east-1.amazonaws.com/k", [], "", @creds)

      auth1 = List.keyfind(h1, "authorization", 0)
      auth2 = List.keyfind(h2, "authorization", 0)

      assert auth1 === auth2
    end
  end

  describe "sign_query/5" do
    test "returns a URL with the six SigV4 presign query params" do
      url =
        Signer.sign_query(
          :get,
          "https://examplebucket.s3.us-east-1.amazonaws.com/test.txt",
          [],
          3600,
          @creds
        )

      query = URI.parse(url).query

      assert query =~ "X-Amz-Algorithm=AWS4-HMAC-SHA256"
      assert query =~ "X-Amz-Credential="
      assert query =~ "X-Amz-Date=20250115T120000Z"
      assert query =~ "X-Amz-Expires=3600"
      assert query =~ "X-Amz-SignedHeaders=host"
      assert query =~ "X-Amz-Signature="
    end

    test "preserves path and host" do
      url =
        Signer.sign_query(
          :get,
          "https://examplebucket.s3.us-east-1.amazonaws.com/folder/file.bin",
          [],
          600,
          @creds
        )

      uri = URI.parse(url)

      assert uri.host === "examplebucket.s3.us-east-1.amazonaws.com"
      assert uri.path === "/folder/file.bin"
    end

    test "security_token is folded into the query as X-Amz-Security-Token" do
      creds = Map.put(@creds, :token, "session-xyz")

      url = Signer.sign_query(:get, "https://b.s3.us-east-1.amazonaws.com/k", [], 60, creds)

      assert URI.parse(url).query =~ "X-Amz-Security-Token=session-xyz"
    end

    test "expires_in is reflected in X-Amz-Expires" do
      url = Signer.sign_query(:get, "https://b.s3.us-east-1.amazonaws.com/k", [], 900, @creds)

      assert URI.parse(url).query =~ "X-Amz-Expires=900"
    end

    test "signature is deterministic for pinned `now`" do
      url1 = Signer.sign_query(:get, "https://b.s3.us-east-1.amazonaws.com/k", [], 60, @creds)
      url2 = Signer.sign_query(:get, "https://b.s3.us-east-1.amazonaws.com/k", [], 60, @creds)

      assert url1 === url2
    end

    test "preserves pre-existing query params" do
      url =
        Signer.sign_query(
          :put,
          "https://b.s3.us-east-1.amazonaws.com/k?partNumber=1&uploadId=abc",
          [],
          60,
          @creds
        )

      query = URI.parse(url).query

      assert query =~ "partNumber=1"
      assert query =~ "uploadId=abc"
      assert query =~ "X-Amz-Signature="
    end
  end

  describe "presign_post_policy/4" do
    test "returns fields map with required POST policy entries" do
      conditions = [
        %{"bucket" => "examplebucket"},
        %{"key" => "uploads/file.txt"},
        ["content-length-range", 1, 104_857_600]
      ]

      result =
        Signer.presign_post_policy(
          "https://examplebucket.s3.us-east-1.amazonaws.com",
          conditions,
          3600,
          @creds
        )

      assert result.url === "https://examplebucket.s3.us-east-1.amazonaws.com"

      for key <- [
            "policy",
            "x-amz-algorithm",
            "x-amz-credential",
            "x-amz-date",
            "x-amz-signature"
          ] do
        assert Map.has_key?(result.fields, key)
      end

      assert result.fields["x-amz-algorithm"] === "AWS4-HMAC-SHA256"
    end

    test "policy decodes to a JSON object with the expected conditions" do
      conditions = [%{"bucket" => "b"}, %{"key" => "k"}]

      result =
        Signer.presign_post_policy("https://b.s3.us-east-1.amazonaws.com", conditions, 60, @creds)

      {:ok, decoded} = Base.decode64(result.fields["policy"])
      policy = :json.decode(decoded)

      assert Map.has_key?(policy, "expiration")
      assert is_list(policy["conditions"])
      assert %{"bucket" => "b"} in policy["conditions"]
      assert %{"key" => "k"} in policy["conditions"]
    end

    test "signature matches an HMAC-SHA256 over the base64 policy with the SigV4 signing key" do
      result =
        Signer.presign_post_policy(
          "https://b.s3.us-east-1.amazonaws.com",
          [%{"bucket" => "b"}, %{"key" => "k"}],
          60,
          @creds
        )

      policy_b64 = result.fields["policy"]

      k_date = :crypto.mac(:hmac, :sha256, "AWS4" <> @creds.secret_access_key, "20250115")
      k_region = :crypto.mac(:hmac, :sha256, k_date, @creds.region)
      k_service = :crypto.mac(:hmac, :sha256, k_region, @creds.service)
      signing_key = :crypto.mac(:hmac, :sha256, k_service, "aws4_request")

      expected =
        :hmac
        |> :crypto.mac(:sha256, signing_key, policy_b64)
        |> Base.encode16(case: :lower)

      assert result.fields["x-amz-signature"] === expected
    end

    test "security_token adds x-amz-security-token to fields and policy conditions" do
      creds = Map.put(@creds, :token, "tok-123")

      result =
        Signer.presign_post_policy(
          "https://b.s3.us-east-1.amazonaws.com",
          [%{"bucket" => "b"}, %{"key" => "k"}],
          60,
          creds
        )

      assert result.fields["x-amz-security-token"] === "tok-123"

      {:ok, decoded} = Base.decode64(result.fields["policy"])
      policy = :json.decode(decoded)

      assert %{"x-amz-security-token" => "tok-123"} in policy["conditions"]
    end
  end
end
