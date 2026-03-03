defmodule AWS.Lang.Default do
  @moduledoc false

  @behaviour AWS.Lang

  def normalize("e_tag"), do: "etag"
  def normalize(value), do: value
end
