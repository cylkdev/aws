defmodule AWS.Organizations.Operation do
  @moduledoc """
  Pure-data request descriptor for an AWS Organizations JSON 1.1 call.

  Built by `AWS.Organizations` and handed to `AWS.Client.execute/1`.
  Organizations is a global service pinned to `us-east-1` for
  signing; the facade enforces that when populating the struct.
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
