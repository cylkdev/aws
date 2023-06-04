defmodule AWS.Util do
  @moduledoc """
  Utility functions
  """

  @doc """
  Converts all string keys to atoms

  ### Example

      iex> SharedUtils.Enum.atomize_keys(%{"test" => 5, hello: 4})
      %{test: 5, hello: 4}

      iex> SharedUtils.Enum.atomize_keys([%{"a" => 5}, %{b: 2}])
      [%{a: 5}, %{b: 2}]
  """
  @spec atomize_keys(Enum.t()) :: Enum.t()
  def atomize_keys(map) do
    transform_keys(map, fn
      key when is_binary(key) -> String.to_atom(key)
      key -> key
    end)
  end

  defp transform_keys(map, transform_fn) do
    deep_transform(map, fn {k, v} -> {transform_fn.(k), v} end)
  end

  @doc """
  Deeply transform key value pairs from maps to apply operations on nested maps

  ### Example

      iex> SharedUtils.Enum.deep_transform(%{"test" => %{"item" => 2, "d" => 3}}, fn {k, v} ->
      ...>   if k === "d" do
      ...>     :delete
      ...>   else
      ...>     {String.to_atom(k), v}
      ...>   end
      ...> end)
      %{test: %{item: 2}}
  """
  def deep_transform(map, transform_fn) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      case transform_fn.({k, v}) do
        {k, v} -> Map.put(acc, k, deep_transform(v, transform_fn))
        :delete -> acc
      end
    end)
  end

  def deep_transform(list, transform_fn) when is_list(list) do
    Enum.map(list, &deep_transform(&1, transform_fn))
  end

  def deep_transform(value, _), do: value
end
