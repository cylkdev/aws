defmodule AWS.Serializer do
  @moduledoc false

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
    transform_keys(payload, &deserialize_key/1)
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

  defp transform_keys(map, func) when is_map(map) do
    Map.new(map, fn {key, value} -> {func.(key), transform_keys(value, func)} end)
  end

  defp transform_keys([], _func) do
    []
  end

  defp transform_keys([head | tail], func) do
    [transform_keys(head, func) | transform_keys(tail, func)]
  end

  defp transform_keys({key, value}, func) do
    {func.(key), transform_keys(value, func)}
  end

  defp transform_keys(value, _func), do: value
end
