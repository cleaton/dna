defmodule Dna.Storage.Storage.KV do
  alias Dna.Db.Storage
  defstruct [:key, updates: %{}, changes: []]
  @type change :: {key :: String.t(), value :: term()} | {key :: String.t(), nil}
  @type t :: %__MODULE__{
          key: term(),
          updates: %{String.t() => term()},
          changes: [change]
        }

  defimpl Dna.Storage do
    def async_persist(%KV{key: mkey, changes: changes}, opaque) do
      Storage.KV.mutate(mkey, changes, opaque)
    end
  end

  @doc """
  Read a value from the storage.
  """
  def read(%__MODULE__{key: mkey, updates: updates}, key) do
    case updates do
      %{^key => value} -> {:ok, value}
      _ -> Storage.KV.read(mkey, key)
    end
  end

  @doc """
  List key -> values from the storage.
  This function does not consider pending writes,
  so it may return stale data if write is called earlier in the same handler
  """
  def list(%__MODULE__{key: mkey}, prefix \\ nil, limit \\ 100) do
    Storage.KV.list(mkey, prefix, limit)
  end

  @doc """
  Delete a value from the storage.
  """
  def delete(%__MODULE__{updates: updates, changes: changes} = s, key) do
    Map.put(updates, key, nil)
    changes = [{key, nil} | changes]
    %__MODULE__{s | updates: updates, changes: changes}
  end

  @doc """
  Write a value to the storage.
  """
  def write(%__MODULE__{updates: updates, changes: changes} = s, key, value) do
    Map.put(updates, key, value)
    changes = [{key, value} | changes]
    %__MODULE__{s | updates: updates, changes: changes}
  end

  @doc """
  persist all pending mutations to the storage.
  In most cases there is no need to call this manually as data is automatically pesisted at the end of the handler.
  """
  def persist(%__MODULE__{key: mkey, changes: changes} = s) do
    # TODO: write to storage
    :ok = Storage.KV.mutate(mkey, changes)
    %__MODULE__{s | changes: []}
  end
end
