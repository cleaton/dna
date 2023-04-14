defmodule Dna.Server.Utils do
  def pm(module, partition), do: Module.concat(module, Integer.to_string(partition))
  def partition(key), do: :erlang.phash2(key, System.schedulers_online())
end
