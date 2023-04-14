defmodule Dna.Server.Partition do
  use GenServer
  import Dna.Server.Utils
  alias Dna.DB
  alias Dna.Server.ObjectRegistry
  alias Dna.Server.ObjectSupervisor

  # TODO: use persistent storage instead of module concat?

  def child_spec(partition) do
    id = pm(__MODULE__, partition)

    %{
      id: id,
      start: {__MODULE__, :start_link, [[partition: partition]]}
    }
  end

  def start_link(args) do
    partition = Keyword.get(args, :partition)
    GenServer.start_link(__MODULE__, args, name: pm(__MODULE__, partition))
  end

  def lookup(key) do
    registry = pm(ObjectRegistry, partition(key))
    Registry.lookup(registry, key)
  end

  def try_claim(key, existing) do
    GenServer.call(pm(__MODULE__, partition(key)), {:try_claim, key, existing})
  end

  @impl true
  def init(args) do
    partition = Keyword.get(args, :partition)
    registry_name = pm(ObjectRegistry, partition)
    supervisor_name = pm(ObjectSupervisor, partition)

    {:ok, _} =
      Registry.start_link(keys: :unique, name: registry_name)

    {:ok, supervisor} =
      DynamicSupervisor.start_link(
        strategy: :one_for_one,
        name: supervisor_name
      )

    {:ok, %{registry: registry_name, supervisor: supervisor, me: Dna.Server.Cluster.server()}}
  end

  @impl true
  def handle_call({:try_claim, key, existing}, _from, %{registry: registry, me: me, supervisor: supervisor} = state) do
    result = case Registry.lookup(registry, key) do
      [{pid, _meta}] -> {:ok, pid}
      [] -> try_claim(supervisor, registry, key, me, existing)
    end
    {:reply, result, state}
  end

  defp try_claim(supervisor, registry, key, me, me) do
    {:ok, start_child(supervisor, registry, key)}
  end

  defp try_claim(supervisor, registry, key, me, dead_or_missing) do
    case Storage.Actors.claim(key, me, dead_or_missing) do
      :ok -> {:active, start_child(supervisor, registry, key)}
      _ -> {:error, :claim_failed}
    end
  end

  defp start_child(supervisor, registry, key) do
    registry_key = {:via, Registry, {registry, key}}
    case DynamicSupervisor.start_child(supervisor, {Dna.Server.ActorInstance, {key, registry_key}}) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
