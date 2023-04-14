defmodule Dna.Server.Cluster do
  alias Dna.DB.Nodes
  use GenServer
  @max_age 15_000
  @alive_threshold 10_000

  @type timestamp_ms :: integer()
  @type id :: {timestamp_ms(), integer()}



  def server_status({ts, _} = id) do
    case :ets.lookup(__MODULE__, id) do
      [{^id, :remote, node, heartbeat, _, _}] ->
        if is_alive?(heartbeat), do: {:alive, node}, else: :dead
      [{^id, :local, node, _, _, _}] -> {:alive, node}
      [] ->
        dead? = System.system_time(:millisecond) - @max_age > ts
        if dead?, do: :dead, else: :unknown
    end
  end

  def is_alive?(ts) do
    now = System.system_time(:millisecond)
    now - @alive_threshold < ts
  end

  def server(), do: :persistent_term.get({__MODULE__, :server})

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl true
  def init(_) do
    cluster = Application.fetch_env!(:dna, :cluster)
    :ets.new(__MODULE__, [:named_table, :protected, :ordered_set, {:read_concurrency, true}])
    <<rand::little-signed-integer-size(64)>> = :crypto.strong_rand_bytes(8)
    ts = System.system_time(:millisecond)
    id = {ts, rand}
    :persistent_term.put({__MODULE__, :server}, id)
    state = %{id: id, cluster: cluster}
    peers = refresh(state)
    Enum.each(peers, fn {_id, node, _heartbeat, _load, _draining} ->
      if node != Node.self() do
        GenServer.cast({__MODULE__, node}, :refresh)
      end
    end)
    Process.send_after(self(), :refresh, 5_000)
    {:ok, state}
  end

  @impl true
  def handle_info(
        :refresh,
        state
      ) do
        refresh(state)
        Process.send_after(self(), :refresh, 5_000)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        :refresh,
        state
      ) do
        refresh(state)
    {:noreply, state}
  end

  defp refresh(%{cluster: cluster, id: id}) do
    ts = System.system_time(:millisecond)
    update_heartbeat(cluster, id, ts)
    peers = update_cluster(cluster, id, ts)
    :ets.insert(__MODULE__, {:last_refresh, System.system_time(:millisecond)})
    peers
  end

  defp update_cluster(cluster, id, ts) do
    peers = Nodes.list(cluster, ts - @max_age)
    Enum.each(peers, fn {nid, node, heatbeat, load, draining} ->
      true = case nid do
        ^id -> :ets.insert(__MODULE__, {id, :local, node, heatbeat, load, draining})
        _ -> :ets.insert(__MODULE__, {nid, :remote, node, heatbeat, load, draining})
      end
      Node.connect(node)
    end)
    peers
  end

  defp update_heartbeat(cluster, id, ts) do
    node = Atom.to_string(Node.self())
    Nodes.add(cluster, id, node, ts, 0.0, false)
  end
end
