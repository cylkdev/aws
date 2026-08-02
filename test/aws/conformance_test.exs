defmodule AWS.ConformanceTest do
  @moduledoc """
  Regression tests for the conformance defects found by auditing this library
  against the live AWS API references.

  Everything here is a pure function, so these assert on the exact bytes the
  library would put on the wire without standing up a transport.
  """

  use ExUnit.Case, async: true

  test "a caller-supplied host is signed once, not twice" do
    headers =
      AWS.Signer.sign(
        :put,
        "https://bucket.s3.amazonaws.com/k",
        [{"host", "bucket.s3.amazonaws.com"}, {"content-type", "text/plain"}],
        "body",
        %{
          access_key_id: "AK",
          secret_access_key: "SK",
          region: "us-east-1",
          service: "s3",
          now: DateTime.utc_now()
        }
      )

    authorization = headers |> Enum.find(fn {k, _} -> k == "authorization" end) |> elem(1)
    signed = Regex.run(~r/SignedHeaders=([^,]+)/, authorization) |> Enum.at(1)

    assert Enum.count(String.split(signed, ";"), &(&1 == "host")) == 1
    assert Enum.count(headers, fn {k, _} -> k == "host" end) == 1
  end

  test "a caller-supplied x-amz-date is signed once, not twice" do
    headers =
      AWS.Signer.sign(
        :get,
        "https://bucket.s3.amazonaws.com/k",
        [{"x-amz-date", "19700101T000000Z"}],
        "",
        %{
          access_key_id: "AK",
          secret_access_key: "SK",
          region: "us-east-1",
          service: "s3",
          now: DateTime.utc_now()
        }
      )

    authorization = headers |> Enum.find(fn {k, _} -> k == "authorization" end) |> elem(1)
    signed = Regex.run(~r/SignedHeaders=([^,]+)/, authorization) |> Enum.at(1)

    assert Enum.count(String.split(signed, ";"), &(&1 == "x-amz-date")) == 1
    assert Enum.count(headers, fn {k, _} -> k == "x-amz-date" end) == 1
  end

  test "put_bucket_encryption emits a real SSEAlgorithm when none is given" do
    xml = AWS.S3.XMLBuilder.build_bucket_encryption([])

    assert xml =~ "<SSEAlgorithm>AES256</SSEAlgorithm>"
    refute xml =~ "<SSEAlgorithm></SSEAlgorithm>"
  end

  test "a lifecycle rule without :status defaults to Enabled instead of raising" do
    xml = AWS.S3.XMLBuilder.build_lifecycle_configuration([%{id: "r", expiration: %{days: 1}}])

    assert xml =~ "<Status>Enabled</Status>"
  end

  test "put_public_access_block emits only the flags supplied" do
    xml = AWS.S3.XMLBuilder.build_public_access_block(block_public_acls: true)

    assert xml =~ "<BlockPublicAcls>true</BlockPublicAcls>"
    refute xml =~ "IgnorePublicAcls"
    refute xml =~ "BlockPublicPolicy"
    refute xml =~ "RestrictPublicBuckets"
  end

  test "a 200 response carrying an Error body is not reported as success" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Error><Code>InternalError</Code><Message>We encountered an internal error.</Message><RequestId>abc</RequestId></Error>
    """

    assert {:error, %ErrorMessage{details: details}} =
             AWS.S3.XMLParser.parse_complete_multipart(xml)

    assert details.code == "InternalError"

    assert {:error, %ErrorMessage{}} = AWS.S3.XMLParser.parse_copy_object_result(xml)
  end

  test "a successful CompleteMultipartUpload body still parses" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <CompleteMultipartUploadResult><Location>https://x/k</Location><Bucket>b</Bucket><Key>k</Key><ETag>"e"</ETag></CompleteMultipartUploadResult>
    """

    assert %{bucket: "b", key: "k"} = AWS.S3.XMLParser.parse_complete_multipart(xml)
  end

  test "an ini value containing # is not truncated" do
    parsed =
      AWS.Credentials.INI.parse("""
      [p]
      secret = abc#def
      url = https://example.com/x#fragment
      commented = value # trailing comment
      """)

    assert parsed["p"]["secret"] == "abc#def"
    assert parsed["p"]["url"] == "https://example.com/x#fragment"
    assert parsed["p"]["commented"] == "value"
  end

  test "a whole-line ini comment is still ignored" do
    parsed =
      AWS.Credentials.INI.parse("""
      [p]
      # this line is a comment
      key = value
      """)

    assert parsed["p"] == %{"key" => "value"}
  end

  test "Organizations ignores a caller region and uses the global endpoint" do
    {:ok, op} =
      AWS.Organizations.build_operation("ListRoots", %{},
        access_key_id: "AK",
        secret_access_key: "SK",
        region: "eu-west-1"
      )

    assert op.url == "https://organizations.us-east-1.amazonaws.com/"
    assert op.region == "us-east-1"
  end

  test "Organizations stays inside the GovCloud partition" do
    {:ok, op} =
      AWS.Organizations.build_operation("ListRoots", %{},
        access_key_id: "AK",
        secret_access_key: "SK",
        region: "us-gov-east-1"
      )

    assert op.url == "https://organizations.us-gov-west-1.amazonaws.com/"
    assert op.region == "us-gov-west-1"
  end

  test "presigned POST form fields keep their literal AWS names" do
    {:ok, result} =
      AWS.S3.presign_post("b", "k.txt",
        access_key_id: "AK",
        secret_access_key: "SK",
        region: "us-east-1"
      )

    keys = Map.keys(result.fields)

    assert "policy" in keys
    assert "x-amz-algorithm" in keys
    assert "x-amz-credential" in keys
    assert "x-amz-signature" in keys
    refute Enum.any?(keys, &is_atom/1)
  end

  test "an S3 object key with reserved characters signs the path it sends" do
    {:ok, config} =
      AWS.S3.resolve_config(
        access_key_id: "AK",
        secret_access_key: "SK",
        region: "us-east-1"
      )

    url = AWS.S3.build_url(config, "bucket", "my file+a:b#c.txt", %{})

    # encode_key/1 applies AWS's UriEncode, so the signer can sign the path
    # verbatim and still match the wire.
    assert URI.parse(url).path == "/my%20file%2Ba%3Ab%23c.txt"
  end
end
