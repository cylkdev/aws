defmodule AWS.Utils do
  @moduledoc false

  def transform_keys(map, func) when is_map(map) do
    Map.new(map, fn {key, value} -> {func.(key), transform_keys(value, func)} end)
  end

  def transform_keys([], _func) do
    []
  end

  def transform_keys([head | tail], func) do
    [transform_keys(head, func) | transform_keys(tail, func)]
  end

  def transform_keys({key, value}, func) do
    {func.(key), transform_keys(value, func)}
  end

  def transform_keys(value, _func), do: value
end
