defmodule AWS.Serializer do
  @moduledoc false

  alias AWS.Utils

  @doc """
  Deserializes a payload by converting all keys to snake_case and atoms.

  ## Examples

      iex> AWS.Serializer.deserialize(%{"Hello-World" => "test"})
      %{hello_world: "test"}

      iex> AWS.Serializer.deserialize(%{"Hello World" => "test"})
      %{hello_world: "test"}

      iex> AWS.Serializer.deserialize(%{"HelloWorld" => "test"})
      %{hello_world: "test"}
  """
  @spec deserialize(any()) :: any()
  def deserialize(payload) do
    Utils.transform_keys(payload, &deserialize_key/1)
  end

  defp deserialize_key(key) when is_binary(key) do
    key
    |> String.trim()
    |> String.replace("\"", "")
    |> normalize_key()
    |> Recase.to_snake()
    |> String.to_atom()
  end

  defp deserialize_key(key), do: key

  defp normalize_key("e_tag"), do: "etag"
  defp normalize_key(value), do: value
end
