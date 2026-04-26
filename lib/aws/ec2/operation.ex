defmodule AWS.EC2.Operation do
  @moduledoc """
  Pure-data request descriptor for an AWS EC2 Query protocol call.

  Built by `AWS.EC2` and handed to `AWS.Client.execute/1`. The body
  is a form-urlencoded binary with `Action` and `Version` already
  merged in; the response is raw XML that `AWS.EC2` parses with
  `SweetXml`.

  EC2 is a regional service; the facade resolves the host to
  `ec2.<region>.amazonaws.com` and signs under that region.
  """

  @enforce_keys [
    :method,
    :url,
    :headers,
    :body,
    :service,
    :region,
    :access_key_id,
    :secret_access_key
  ]
  defstruct [
    :method,
    :url,
    :headers,
    :body,
    :service,
    :region,
    :access_key_id,
    :secret_access_key,
    :security_token,
    http: []
  ]

  @type t :: %__MODULE__{
          method: :post,
          url: String.t(),
          headers: [{String.t(), String.t()}],
          body: iodata,
          service: String.t(),
          region: String.t(),
          access_key_id: String.t(),
          secret_access_key: String.t(),
          security_token: String.t() | nil,
          http: keyword
        }
end
