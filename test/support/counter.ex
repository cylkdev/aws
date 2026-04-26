defmodule AWS.Counter do
  @moduledoc false
  @table __MODULE__

  def start do
    :ets.new(@table, [:named_table, :public, :set])
  end

  def increment(key) do
    :ets.update_counter(@table, key, {2, 1}, {key, 0})
  end
end
