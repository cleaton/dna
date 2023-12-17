defmodule Dna.Server.Cluster do
  alias Dna.DB.Nodes
  use GenServer

  @alive_threshold 10_000

  @type timestamp_ms :: integer()
  @type id :: {timestamp_ms(), integer()}
  defmodule State do
    @type timestamp_ms :: integer()
    @type id :: {timestamp_ms(), integer()}
    defstruct [:cluster, :id]
    @type t :: %__MODULE__{
            cluster: String.t(),
            id: id(),
          }
  end

  defmodule ClusterNode do
    @type timestamp_ms :: integer()
    @type id :: {timestamp_ms(), integer()}
    defstruct [:id, :type, :node, :heartbeat, :last_beat_update, :load, :draining]

    @expire_after 10_000

    @type t :: %__MODULE__{
            id: id(),
            type: :local | :remote,
            node: atom(),
            heartbeat: integer(),
            last_beat_update: integer(),
            load: float(),
            draining: boolean()
          }
    def expired?(%__MODULE__{last_beat_update: last_update}) do
      System.monotonic_time(:millisecond) - last_update > @expire_after
    end

    def new_or_update(id, type, node, heartbeat, load, draining) do
      cluster_node = case :ets.lookup(Dna.Server.Cluster, id) do
        [{^id, cluster_node}] ->
          if cluster_node.heartbeat != heartbeat do
            %__MODULE__{cluster_node | heartbeat: heartbeat, last_beat_update: System.monotonic_time(:millisecond), load: load, draining: draining}
          else
            cluster_node
          end

        [] ->
          %__MODULE__{
            id: id,
            type: type,
            node: node,
            heartbeat: heartbeat,
            last_beat_update: System.monotonic_time(:millisecond),
            load: load,
            draining: draining
          }
      end
      :ets.insert(Dna.Server.Cluster, {id, cluster_node})
      cluster_node
    end
  end

  def server_status({ts, _} = id) do
    must_be_healty()
    case :ets.lookup(__MODULE__, id) do
      [{^id, %ClusterNode{} = cluster_node}] ->
        if cluster_node.type == :local do
          {:alive, cluster_node.node}
        else
          if ClusterNode.expired?(cluster_node), do: :dead, else: {:alive, cluster_node.node}
        end

      [] ->
        dead? = System.system_time(:millisecond) - @alive_threshold > ts
        if dead?, do: :dead, else: :unknown
    end
  end

  def must_be_healty() do
    healthy = case :ets.lookup(__MODULE__, :last_refresh) do
      [{:last_refresh, last_refresh}] ->
        System.monotonic_time(:millisecond) - last_refresh < @alive_threshold

      [] ->
        false
    end
    if not healthy do
      System.halt(1)
    end
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
    state = %State{cluster: cluster, id: id}
    peers = refresh(state)

    Enum.each(peers, fn (%ClusterNode{type: type, node: node}) ->
      if type == :remote do
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

  defp refresh(%State{cluster: cluster, id: id}) do
    update_me(cluster, id)
    peers = update_cluster(cluster, id)
    :ets.insert(__MODULE__, {:last_refresh, System.monotonic_time(:millisecond)})
    peers
  end

  defp update_cluster(cluster, id) do
    peers = Nodes.list(cluster)
    Enum.map(peers, fn {nid, node, heartbeat, load, draining} ->
      case nid do
        ^id -> ClusterNode.new_or_update(id, :local, node, heartbeat, load, draining)
        _ ->
          cluster_node = ClusterNode.new_or_update(nid, :remote, node, heartbeat, load, draining)
          if ClusterNode.expired?(cluster_node) do
            :ets.delete(__MODULE__, nid)
            Nodes.delete(cluster, nid)
          end
          cluster_node
      end
    end)
  end

  defp update_me(cluster, id) do
    load = :cpu_sup.avg1() / 256.0
    ts = System.monotonic_time(:millisecond)
    node = Atom.to_string(Node.self())
    Nodes.add(cluster, id, node, ts, load, false)
  end
end
