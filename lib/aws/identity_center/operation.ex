defmodule AWS.IdentityCenter.Operation do
  @moduledoc """
  Pure-data request descriptor for an IAM Identity Center JSON 1.1
  call against either the `sso-admin` or `identitystore` sub-service.

  Built by `AWS.IdentityCenter` and handed to `AWS.Client.execute/1`.
  The `:service` field picks the signing scope (`"sso"` vs
  `"identitystore"`); the facade also selects the matching host and
  `x-amz-target` prefix when populating the struct.
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
