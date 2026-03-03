defmodule AWS.Serializer do
  @moduledoc false

  alias AWS.{Lang, Utils}

  @doc """
  Deserializes a payload by converting all keys to snake_case and atoms.

  ## Options

  - `key_normalizer` - A module that implements a `normalize/1` function for key normalization. Defaults to `AWS.Lang`.

  ## Examples

      iex> AWS.Serializer.deserialize(%{"Hello-World" => "test"})
      %{hello_world: "test"}

      iex> AWS.Serializer.deserialize(%{"Hello World" => "test"})
      %{hello_world: "test"}

      iex> AWS.Serializer.deserialize(%{"HelloWorld" => "test"})
      %{hello_world: "test"}
  """
  @spec deserialize(any(), keyword()) :: any()
  def deserialize(payload, opts \\ []) do
    Utils.transform_keys(payload, &deserialize_key(&1, opts))
  end

  defp deserialize_key(key, opts) when is_binary(key) do
    key
    |> String.trim()
    |> String.replace("\"", "")
    |> Lang.normalize(opts)
    |> Recase.to_snake()
    |> String.to_atom()
  end

  defp deserialize_key(key, _opts) do
    key
  end
end
