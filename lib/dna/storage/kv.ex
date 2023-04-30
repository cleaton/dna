defmodule Dna.Storage.KV do
  alias Dna.DB.Storage
  defstruct [:key, updates: %{}, changes: []]
  @type change :: {key :: String.t(), value :: term()} | {key :: String.t(), nil}
  @type t :: %__MODULE__{
          key: Dna.Types.ActorName.t(),
          updates: %{String.t() => term()},
          changes: [change]
        }

  def new(actor_name \\  nil) do
    %__MODULE__{key: actor_name}
  end

  defimpl Dna.Storage do
    alias Dna.Storage.KV
    def persist(%KV{key: mkey, changes: changes} = s) do
      opaque = {:persist, make_ref()}
      :ok = Storage.Kv.mutate(mkey, changes, opaque)
      {:async, s, opaque}
    end

    def init(%KV{} = s, actor_name) do
      {:sync, %KV{s | key: actor_name}}
    end

    def on_opaque(%KV{} = s, {:persist, _ref}, {:ok, _queryresult}) do
      {:sync, %KV{s | updates: %{}, changes: []}}
    end

    def on_opaque(%KV{}, {:persist, _ref}, {:error, _queryresult}) do
      # TODO: retry on some errors?
      {:error, "persist failed"}
    end
  end

  @doc """
  Read a value from the storage.
  """
  def read(%__MODULE__{key: mkey, updates: updates}, key) do
    case updates do
      %{^key => value} -> {:ok, value}
      _ -> Storage.Kv.read(mkey, key)
    end
  end

  @doc """
  List key -> values from the storage.
  This function does not consider pending writes,
  so it may return stale data if write is called earlier in the same handler
  """
  def list(%__MODULE__{key: mkey}, prefix \\ nil, limit \\ 100) do
    Storage.Kv.list(mkey, prefix, limit)
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

  @spec persist(Dna.Storage.KV.t()) :: Dna.Storage.KV.t()
  @doc """
  persist all pending mutations to the storage.
  In most cases there is no need to call this manually as data is automatically pesisted at the end of the handler.
  """
  def persist(%__MODULE__{key: mkey, changes: changes} = s) do
    :ok = Storage.Kv.mutate(mkey, changes)
    %__MODULE__{s | changes: []}
  end
end
