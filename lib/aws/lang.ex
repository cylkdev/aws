defmodule AWS.Lang do
  @moduledoc false

  @callback normalize(String.t()) :: String.t()

  def normalize(value, opts) do
    adapter = opts[:key_normalizer] || AWS.Lang.Default
    adapter.normalize(value)
  end
end
