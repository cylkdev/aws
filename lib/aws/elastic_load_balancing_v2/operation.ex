defmodule AWS.ElasticLoadBalancingV2.Operation do
  @moduledoc """
  Pure-data request descriptor for an AWS Elastic Load Balancing v2 Query
  protocol call.

  Built by `AWS.ElasticLoadBalancingV2` and handed to `AWS.Client.execute/1`.
  The body is a form-urlencoded binary with `Action` and `Version` already
  merged in; the response is raw XML that `AWS.ElasticLoadBalancingV2`
  parses with `SweetXml`.

  ELBv2 is regional; the facade fills `:region` from resolved config and
  routes to `elasticloadbalancing.{region}.amazonaws.com`.
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
