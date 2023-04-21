defmodule Dna.Server do
  use Supervisor
  alias Dna.DB
  alias Dna.Server.Partition

  @max_retries 10

  # {namespace, actor_id, name}
  @type key :: {String.t(), integer(), String.t()}
  @type call_types :: :call | :cast

  def call(actor, key, msg), do: execute(actor, :call, key, msg)
  def cast(actor, key, msg), do: execute(actor, :cast, key, msg)
  def execute(actor, type, key, msg), do: execute(actor, type, key, msg, @max_retries)
  def execute(_actor, _type, _key, _msg, 0), do: {:error, :max_retries}

  @spec execute(module(), call_types(), key(), any(), pos_integer()) :: any
  def execute(actor, type, key, msg, retries) do
    me = Dna.Server.Cluster.server()
    retries = retries - 1

    case server_lookup(key) do
      ^me ->
        case Partition.lookup(key) do
          [{pid, _meta}] ->
            do_type(type, pid, msg)

          [] ->
            schedule(actor, key, me)
            |> post_schedule(actor, type, key, msg, retries)
        end

      :not_found ->
        schedule(actor, key)
        |> post_schedule(actor, type, key, msg, retries)

      server ->
        current_node = Node.self()

        status = Dna.Server.Cluster.server_status(server)
        IO.inspect(server)
        IO.inspect(status)
        case status do
          :dead ->
            Cachex.del(:dna_actors, key)
            schedule(actor, key, server)
            |> post_schedule(actor, type, key, msg, retries)

          {:alive, ^current_node} ->
            # Missconfigured cluster or node failure?, try and wait timeout
            Process.sleep((@max_retries - retries) * 100)
            execute(actor, type, key, msg, retries)

          {:alive, node} ->
            :erpc.call(node, Dna.Server, :execute, [actor, type, key, msg, retries])
        end
    end
  end

  def schedule(actor, key, existing_server \\ nil) do
    # TODO allow to override the default scheduling strategy, for example hash based on the key
    Partition.try_claim(actor, key, existing_server)
  end

  defp post_schedule({:ok, pid}, _actor, type, _key, msg, _retries), do: do_type(type, pid, msg)
  defp post_schedule({:error, _}, actor, type, key, msg, retries), do: execute(actor, type, key, msg, retries)

  defp do_type(:call, pid, msg), do: GenServer.call(pid, msg)
  defp do_type(:cast, pid, msg), do: GenServer.cast(pid, msg)

  defp server_lookup(key) do
    {_, res} = Cachex.fetch(:dna_actors, key, fn ({namespace, module_id, name}) ->
      case DB.Actors.where_is(namespace, module_id, name) do
        :not_found -> {:ignore, :not_found}
        res -> {:commit, res}
      end
    end)
    res
  end

  ###### PARTITION SUPERVISOR ######

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = create_partitions()
    Supervisor.init(children, strategy: :one_for_all)
  end

  defp create_partitions() do
    for partition <- 0..(System.schedulers_online() - 1) do
      Partition.child_spec(partition)
    end
  end
end
