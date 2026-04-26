defmodule AWS.S3.Operation do
  @moduledoc """
  Pure-data request descriptor for an S3 REST/XML call.

  Built by `AWS.S3` and handed to `AWS.Client.execute/1`. Unlike the
  JSON 1.1 Operations in this library, S3's struct carries the
  protocol-flexibility fields the signer and HTTP dispatcher need:

    * `:payload_hash` — signer override (e.g. `"UNSIGNED-PAYLOAD"`
      for streaming uploads and presigned URLs).
    * `:stream_upload` — when `true`, body is an `Enumerable` and
      dispatch goes through `HTTP.stream_upload/5`.
    * `:stream_response` — when `true`, the response exposes
      `body_stream` instead of a buffered `body`.

  The struct does not carry a query map or a bucket/key; URL
  composition happens in `AWS.S3.build_url/4` and the resulting URL
  is stored in `:url`.
  """

  @enforce_keys [
    :method,
    :url,
    :headers,
    :service,
    :region,
    :access_key_id,
    :secret_access_key
  ]
  defstruct [
    :method,
    :url,
    :headers,
    :service,
    :region,
    :access_key_id,
    :secret_access_key,
    :security_token,
    :payload_hash,
    body: "",
    stream_upload: false,
    stream_response: false,
    http: []
  ]

  @type method :: :get | :put | :post | :delete | :head
  @type t :: %__MODULE__{
          method: method,
          url: String.t(),
          headers: [{String.t(), String.t()}],
          service: String.t(),
          region: String.t(),
          access_key_id: String.t(),
          secret_access_key: String.t(),
          security_token: String.t() | nil,
          payload_hash: String.t() | nil,
          body: iodata | Enumerable.t(),
          stream_upload: boolean,
          stream_response: boolean,
          http: keyword
        }
end
