defmodule Dna.Server.ActorInstance do
  use GenServer
  alias Dna.Storage
  alias Dna.Types.ActorName

  defmodule S do
    @type event :: Dna.Actor.event()
    @type pending :: %{reference() => atom()}
    @type status ::
            {:pending_storage, pending :: pending(), continue :: term()}
            | :idle

    defstruct [:actor, :actor_name, :buffer, :buffer_size, :status, :storage, :state]

    @type t() :: %__MODULE__{
            actor: module(),
            actor_name: Dna.Types.ActorName.t(),
            buffer: [event()],
            buffer_size: non_neg_integer(),
            status: status(),
            storage: %{atom() => term()},
            state: term()
          }
    def new(actor, actor_name) do
      %__MODULE__{
        actor: actor,
        actor_name: actor_name,
        buffer: [],
        buffer_size: 0
      }
    end
  end

  def start_link({actor, {namespace, module_id, name}, registry_name}) do
    GenServer.start_link(
      __MODULE__,
      %{
        actor_name: %ActorName{namespace: namespace, module_id: module_id, name: name},
        actor: actor
      },
      name: registry_name
    )
  end

  def init(context) do
    state = S.new(context.actor, context.actor_name)
    {:ok, state, {:continue, :init_storage}}
  end

  def handle_continue(:init_storage, %S{actor_name: an, actor: actor} = s) do
    storage = actor.storage()

    case storage_run(storage, fn si -> Storage.init(si, an) end) do
      {:ok, storage} ->
        {:noreply, %S{s | storage: storage}, {:continue, :init}}

      {:pending, storage, pending} ->
        {:noreply, %S{s | storage: storage, status: {:pending_storage, pending, :init}}}
    end
  end

  def handle_continue(:init, %S{actor_name: an, actor: actor, storage: storage} = s) do
    case actor.init(an, storage) do
      {:ok, state} ->
        {:noreply, %S{s | state: state, status: :idle}}

      {:ok, state, storage_change} ->
        case storage_run(storage_change, fn si -> Storage.persist(si) end, storage) do
          {:ok, storage} ->
            {:noreply, %S{s | state: state, storage: storage, status: :idle}}

          {:pending, storage, pending} ->
            {:noreply,
             %S{
               s
               | state: state,
                 storage: storage,
                 status: {:pending_storage, pending, :handle_events}
             }}
        end
    end
  end

  def handle_continue({:after_persist, events}, %S{actor: actor, state: state} = s) do
    {:ok, state} = actor.after_persist(events, state)
    %S{s | state: state} |> actor_events_handler()
  end

  def handle_continue(:handle_events, s), do: actor_events_handler(s)

  def handle_cast(msg, s), do: buffer({:cast, msg}, s) |> actor_events_handler()
  def handle_call(msg, from, s), do: buffer({:call, msg, from}, s) |> actor_events_handler()

  def handle_info(
        {opaque, msg},
        %S{storage: storage, status: {:pending_storage, pending, continue}} = s
      )
      when is_map_key(pending, opaque) do
    %{^opaque => name} = pending
    %{^name => si} = storage
    pending = Map.delete(pending, opaque)

    {storage, pending} =
      case Storage.on_opaque(si, opaque, msg) do
        {:sync, si} -> {%{storage | name => si}, pending}
        {:async, si, opaque} -> {%{storage | name => si}, Map.put(pending, opaque, name)}
      end

    case Kernel.map_size(pending) do
      0 ->
        {:noreply, %S{s | storage: storage, status: :idle}, {:continue, continue}}

      _ ->
        {:noreply, %S{s | storage: storage, status: {:pending_storage, pending, continue}}}
    end
  end

  def handle_info(msg, s), do: buffer({:info, msg}, s) |> actor_events_handler()

  defp buffer(msg, %S{buffer: buffer, buffer_size: bs} = s),
    do: %S{s | buffer: [msg | buffer], buffer_size: bs + 1}

  defp actor_events_handler(%S{buffer_size: 0} = s), do: {:noreply, s}

  defp actor_events_handler(
         %S{status: :idle, actor: actor, buffer: buffer, buffer_size: bs, storage: storage, state: state} = s
       ) do
    {events, buffer} = Enum.split(buffer, 1000)
    bs = if bs > 1000, do: bs - 1000, else: 0
    events = Enum.reverse(events)
    continue = {:after_persist, events}

    case actor.handle_events(events, state, storage) do
      {:ok, state} ->
        {:noreply, %S{s | buffer: buffer, buffer_size: bs, state: state, status: :idle},
         {:continue, continue}}

      {:ok, state, storage_change} ->
        case storage_run(storage_change, fn si -> Storage.persist(si) end, storage) do
          {:ok, storage} ->
            {:noreply,
             %S{s | buffer: buffer, buffer_size: bs, state: state, storage: storage, status: :idle},
             {:continue, continue}}

          {:pending, storage, pending} ->
            {:noreply,
             %S{
               s
               | buffer: buffer,
                 buffer_size: bs,
                 state: state,
                 storage: storage,
                 status: {:pending_storage, pending, continue}
             }}
        end
    end
  end

  defp actor_events_handler(s), do: {:noreply, s}

  defp storage_run(storage, f, merge \\ nil) do
    merge = if is_nil(merge), do: storage, else: merge

    r =
      Enum.reduce(storage, {merge, %{}}, fn {name, s}, {storage, pending} ->
        case f.(s) do
          {:sync, s} ->
            {%{storage | name => s}, pending}

          {:async, s, opaque} ->
            {%{storage | name => s}, Map.put(pending, opaque, name)}
        end
      end)

    case r do
      {storage, pending} when map_size(pending) == 0 -> {:ok, storage}
      {storage, pending} -> {:pending, storage, pending}
    end
  end
end

# defmodule Dna.Server.Actor do
#  @type event :: {:call, from, msg} | {:cast, msg} | {:info, msg}
#  @type reply :: {:reply, to, msg}
#  def init(context) do
#  end
#
#  def handle_events(events, storage, cache) do
#    {replies, state_change, cache, for_after}
#  end
#
#  def after_persist(events, cache, for_after) do
#    {:done, cache}
#  end
# end
