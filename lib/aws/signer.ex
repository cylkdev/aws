defmodule AWS.Signer do
  @moduledoc """
  AWS Signature Version 4 (SigV4) signer.

  Provides three entry points:

    * `sign/5` — header-mode SigV4. Produces `Authorization`, `X-Amz-Date`,
      `X-Amz-Content-Sha256`, and (optionally) `X-Amz-Security-Token`
      headers for calling AWS APIs directly over HTTP.

    * `sign_query/5` — query-string SigV4. Returns a fully-signed URL
      with the SigV4 parameters in the query string. Used for S3
      presigned URLs (`presign`, `presign_part`).

    * `presign_post_policy/4` — signs a base64-encoded policy document
      for HTML form POST uploads. Returns a map of `fields` plus the
      target `url`.

  Service-agnostic: the caller passes `service:` (e.g. `"events"`,
  `"logs"`, `"s3"`) in the creds map.

  Pure functions; no process state. Accepts `now` explicitly so tests
  can pin the timestamp used in signatures.
  """

  @algorithm "AWS4-HMAC-SHA256"
  @unsigned_payload "UNSIGNED-PAYLOAD"

  @type creds :: %{
          required(:access_key_id) => String.t(),
          required(:secret_access_key) => String.t(),
          required(:region) => String.t(),
          required(:service) => String.t(),
          required(:now) => DateTime.t(),
          optional(:token) => String.t() | nil,
          optional(:payload_hash) => String.t()
        }

  @doc """
  Signs a request and returns the complete header list (original headers
  with SigV4 headers appended).

  `headers` is a list of `{name, value}` tuples. Header names may be in
  any case; they are lowercased for signing. `body` is the raw request
  payload (binary).

  Pass `:payload_hash` in `creds` to override the computed body hash.
  Use `"UNSIGNED-PAYLOAD"` for streaming uploads where the body hash
  isn't available up front.
  """
  @spec sign(atom | String.t(), String.t(), [{String.t(), String.t()}], binary, creds) ::
          [{String.t(), String.t()}]
  def sign(method, url, headers, body, creds) do
    method_str = method |> to_string() |> String.upcase()
    uri = URI.parse(url)

    amz_date = format_amz_date(creds.now)
    date_stamp = String.slice(amz_date, 0, 8)
    payload_hash = creds[:payload_hash] || hex_sha256(body)

    base_headers =
      [
        {"host", host_header(uri)},
        {"x-amz-content-sha256", payload_hash},
        {"x-amz-date", amz_date}
      ]
      |> maybe_add_token(creds[:token])
      |> merge_user_headers(headers)

    {canonical_headers, signed_headers} = canonicalize_headers(base_headers)

    canonical_request =
      Enum.join(
        [
          method_str,
          canonical_uri(uri),
          canonical_query(uri),
          canonical_headers,
          signed_headers,
          payload_hash
        ],
        "\n"
      )

    credential_scope = "#{date_stamp}/#{creds.region}/#{creds.service}/aws4_request"

    string_to_sign =
      Enum.join(
        [
          @algorithm,
          amz_date,
          credential_scope,
          hex_sha256(canonical_request)
        ],
        "\n"
      )

    signing_key =
      derive_signing_key(creds.secret_access_key, date_stamp, creds.region, creds.service)

    signature = hex(:crypto.mac(:hmac, :sha256, signing_key, string_to_sign))

    authorization =
      "#{@algorithm} Credential=#{creds.access_key_id}/#{credential_scope}, " <>
        "SignedHeaders=#{signed_headers}, Signature=#{signature}"

    headers
    |> drop_header("authorization")
    |> drop_header("host")
    |> drop_header("x-amz-date")
    |> drop_header("x-amz-content-sha256")
    |> drop_header("x-amz-security-token")
    |> Kernel.++([
      {"host", host_header(uri)},
      {"x-amz-date", amz_date},
      {"x-amz-content-sha256", payload_hash},
      {"authorization", authorization}
    ])
    |> maybe_append_token(creds[:token])
  end

  @doc """
  Returns a signed URL with SigV4 parameters folded into the query
  string. Used for presigned URLs where the caller needs to hand an
  opaque URL to a browser or third party.

  `headers` is a list of headers that must appear on the eventual
  request (at minimum, `host` is always included automatically). For S3
  presigned URLs the typical call passes `headers: []` and the
  signature covers only `host`.

  The payload hash is always `UNSIGNED-PAYLOAD` — the signer cannot
  see the body that a browser or curl will send later.
  """
  @spec sign_query(
          atom | String.t(),
          String.t(),
          [{String.t(), String.t()}],
          non_neg_integer(),
          creds
        ) :: String.t()
  def sign_query(method, url, headers, expires_in, creds) do
    method_str = method |> to_string() |> String.upcase()
    uri = URI.parse(url)

    amz_date = format_amz_date(creds.now)
    date_stamp = String.slice(amz_date, 0, 8)
    credential_scope = "#{date_stamp}/#{creds.region}/#{creds.service}/aws4_request"
    credential = "#{creds.access_key_id}/#{credential_scope}"

    signing_headers = [{"host", host_header(uri)}] ++ normalize_headers(headers)
    {canonical_headers, signed_headers} = canonicalize_headers(signing_headers)

    presign_params =
      maybe_add_query_token(
        [
          {"X-Amz-Algorithm", @algorithm},
          {"X-Amz-Credential", credential},
          {"X-Amz-Date", amz_date},
          {"X-Amz-Expires", Integer.to_string(expires_in)},
          {"X-Amz-SignedHeaders", signed_headers}
        ],
        creds[:token]
      )

    existing_query = decode_query_pairs(uri.query)
    all_query_pairs = existing_query ++ presign_params
    canonical_query = canonicalize_query_pairs(all_query_pairs)

    canonical_request =
      Enum.join(
        [
          method_str,
          canonical_uri(uri),
          canonical_query,
          canonical_headers,
          signed_headers,
          @unsigned_payload
        ],
        "\n"
      )

    string_to_sign =
      Enum.join(
        [
          @algorithm,
          amz_date,
          credential_scope,
          hex_sha256(canonical_request)
        ],
        "\n"
      )

    signing_key =
      derive_signing_key(creds.secret_access_key, date_stamp, creds.region, creds.service)

    signature = hex(:crypto.mac(:hmac, :sha256, signing_key, string_to_sign))

    final_query = canonicalize_query_pairs(all_query_pairs ++ [{"X-Amz-Signature", signature}])
    URI.to_string(%URI{uri | query: final_query})
  end

  @doc """
  Signs a base64-encoded policy document for an S3 POST form upload.

  `url` is the target form action (e.g. `"https://bucket.s3.us-east-1.amazonaws.com"`).
  `conditions` is a list of condition entries — each either a map
  (`%{"bucket" => "my-bucket"}`) or a three-element list
  (`["starts-with", "$key", "uploads/"]`) per the AWS POST policy spec.
  `expires_in` is seconds until the policy expires.

  Returns `%{fields: %{...}, url: url}`. The `fields` map includes the
  required `policy`, `x-amz-algorithm`, `x-amz-credential`,
  `x-amz-date`, and `x-amz-signature` entries (plus
  `x-amz-security-token` when a session token is present). Callers
  merge these into an HTML form.
  """
  @spec presign_post_policy(
          String.t(),
          [map | list],
          non_neg_integer(),
          creds
        ) :: %{fields: map, url: String.t()}
  def presign_post_policy(url, conditions, expires_in, creds) do
    amz_date = format_amz_date(creds.now)
    date_stamp = String.slice(amz_date, 0, 8)

    credential =
      "#{creds.access_key_id}/#{date_stamp}/#{creds.region}/#{creds.service}/aws4_request"

    expiration =
      creds.now
      |> DateTime.shift_zone!("Etc/UTC")
      |> DateTime.add(expires_in, :second)
      |> DateTime.to_iso8601()

    required_conditions =
      maybe_add_token_condition(
        [
          %{"x-amz-algorithm" => @algorithm},
          %{"x-amz-credential" => credential},
          %{"x-amz-date" => amz_date}
        ],
        creds[:token]
      )

    policy_doc = %{"expiration" => expiration, "conditions" => required_conditions ++ conditions}

    policy_json = policy_doc |> :json.encode() |> IO.iodata_to_binary()
    policy_b64 = Base.encode64(policy_json)

    signing_key =
      derive_signing_key(creds.secret_access_key, date_stamp, creds.region, creds.service)

    signature = hex(:crypto.mac(:hmac, :sha256, signing_key, policy_b64))

    fields =
      maybe_put_token_field(
        %{
          "policy" => policy_b64,
          "x-amz-algorithm" => @algorithm,
          "x-amz-credential" => credential,
          "x-amz-date" => amz_date,
          "x-amz-signature" => signature
        },
        creds[:token]
      )

    %{fields: fields, url: url}
  end

  @doc false
  def format_amz_date(%DateTime{} = dt) do
    dt
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  defp host_header(%URI{host: host, port: port, scheme: scheme}) do
    if default_port?(scheme, port) do
      host
    else
      "#{host}:#{port}"
    end
  end

  defp default_port?("https", 443), do: true
  defp default_port?("http", 80), do: true
  defp default_port?(_, nil), do: true
  defp default_port?(_, _), do: false

  defp canonical_uri(%URI{path: nil}), do: "/"
  defp canonical_uri(%URI{path: ""}), do: "/"
  defp canonical_uri(%URI{path: path}), do: path

  defp canonical_query(%URI{query: nil}), do: ""
  defp canonical_query(%URI{query: ""}), do: ""

  defp canonical_query(%URI{query: q}) do
    q
    |> decode_query_pairs()
    |> canonicalize_query_pairs()
  end

  defp decode_query_pairs(nil), do: []
  defp decode_query_pairs(""), do: []

  defp decode_query_pairs(query) when is_binary(query) do
    query
    |> URI.query_decoder()
    |> Enum.map(fn {k, v} -> {k, v || ""} end)
  end

  defp canonicalize_query_pairs(pairs) do
    pairs
    |> Enum.map(fn {k, v} -> {uri_encode(k), uri_encode(v || "")} end)
    |> Enum.sort()
    |> Enum.map_join("&", fn {k, v} -> "#{k}=#{v}" end)
  end

  defp uri_encode(value), do: URI.encode(value, &URI.char_unreserved?/1)

  defp canonicalize_headers(headers) do
    normalized =
      headers
      |> Enum.map(fn {k, v} ->
        {k |> to_string() |> String.downcase(), v |> to_string() |> trim_header_value()}
      end)
      |> Enum.sort_by(fn {k, _} -> k end)

    canonical = Enum.map_join(normalized, "", fn {k, v} -> "#{k}:#{v}\n" end)

    signed = Enum.map_join(normalized, ";", fn {k, _} -> k end)

    {canonical, signed}
  end

  defp trim_header_value(value) do
    value
    |> String.trim()
    |> collapse_internal_whitespace()
  end

  # Collapse runs of spaces in unquoted header values. (Good enough for
  # the simple ASCII header values we produce.)
  defp collapse_internal_whitespace(value) do
    Regex.replace(~r/ +/, value, " ")
  end

  defp derive_signing_key(secret, date_stamp, region, service) do
    k_date = :crypto.mac(:hmac, :sha256, "AWS4" <> secret, date_stamp)
    k_region = :crypto.mac(:hmac, :sha256, k_date, region)
    k_service = :crypto.mac(:hmac, :sha256, k_region, service)
    :crypto.mac(:hmac, :sha256, k_service, "aws4_request")
  end

  defp hex_sha256(data) do
    :sha256 |> :crypto.hash(data) |> hex()
  end

  defp hex(bin), do: Base.encode16(bin, case: :lower)

  defp maybe_add_token(headers, nil), do: headers
  defp maybe_add_token(headers, ""), do: headers
  defp maybe_add_token(headers, token), do: headers ++ [{"x-amz-security-token", token}]

  defp maybe_append_token(headers, token) when is_binary(token) and token !== "" do
    headers ++ [{"x-amz-security-token", token}]
  end

  defp maybe_append_token(headers, _), do: headers

  defp maybe_add_query_token(params, token) when is_binary(token) and token !== "" do
    params ++ [{"X-Amz-Security-Token", token}]
  end

  defp maybe_add_query_token(params, _), do: params

  defp maybe_add_token_condition(conditions, token) when is_binary(token) and token !== "" do
    conditions ++ [%{"x-amz-security-token" => token}]
  end

  defp maybe_add_token_condition(conditions, _), do: conditions

  defp maybe_put_token_field(fields, token) when is_binary(token) and token !== "" do
    Map.put(fields, "x-amz-security-token", token)
  end

  defp maybe_put_token_field(fields, _), do: fields

  defp normalize_headers(headers) do
    Enum.map(headers, fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)
  end

  defp merge_user_headers(base, user) do
    base ++ normalize_headers(user)
  end

  defp drop_header(headers, name) do
    lname = String.downcase(name)
    Enum.reject(headers, fn {k, _} -> k |> to_string() |> String.downcase() === lname end)
  end
end
