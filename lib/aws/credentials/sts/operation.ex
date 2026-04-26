defmodule AWS.Credentials.STS.Operation do
  @moduledoc """
  Pure-data request descriptor for an STS Query protocol call
  (`AssumeRole` and friends) issued during credential resolution.

  Built by `AWS.Credentials.Providers.AssumeRole` and handed to
  `AWS.Client.execute/1`. Because the operation runs during credential
  resolution, the caller must populate the struct with pre-resolved
  source credentials. `AWS.Client.execute/1` signs and dispatches the
  struct as-is, so there is no risk of a resolver loop.
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
