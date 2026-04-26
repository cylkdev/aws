defmodule AWS.Credentials.INI do
  @moduledoc """
  Minimal INI parser for AWS credential and config files.

  Returns every `[section]` found in the file as a map of string keys to
  string values. Section headers and keys are trimmed; inline `#`
  comments are stripped.
  """

  @type sections :: %{optional(String.t()) => %{optional(String.t()) => String.t()}}

  @doc """
  Reads and parses the INI file at `path`.

  Returns `{:ok, sections}` when the file exists and parses cleanly,
  `{:error, :enoent}` when the file is missing, or `{:error, posix}`
  for other read errors.
  """
  @spec read(Path.t()) :: {:ok, sections} | {:error, File.posix()}
  def read(path) do
    case File.read(path) do
      {:ok, contents} -> {:ok, parse(contents)}
      {:error, _} = err -> err
    end
  end

  @doc """
  Parses a full INI document into a `%{section => %{key => value}}` map.
  """
  @spec parse(String.t()) :: sections
  def parse(contents) when is_binary(contents) do
    contents
    |> String.split(~r/\r?\n/)
    |> Enum.reduce({nil, %{}}, &reduce_line/2)
    |> elem(1)
  end

  defp reduce_line(raw_line, {section, acc}) do
    line = raw_line |> String.split("#", parts: 2) |> hd() |> String.trim()

    cond do
      line === "" ->
        {section, acc}

      String.starts_with?(line, "[") and String.ends_with?(line, "]") ->
        new_section = line |> String.slice(1..-2//1) |> String.trim()
        {new_section, Map.put_new(acc, new_section, %{})}

      section !== nil and String.contains?(line, "=") ->
        [k, v] = String.split(line, "=", parts: 2)

        entry =
          Map.update(
            acc,
            section,
            %{String.trim(k) => String.trim(v)},
            &Map.put(&1, String.trim(k), String.trim(v))
          )

        {section, entry}

      true ->
        {section, acc}
    end
  end
end
