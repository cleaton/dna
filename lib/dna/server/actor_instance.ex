defmodule Dna.Server.ActorInstance do
  use GenServer
  alias Dna.Storage

  defmodule S do
    @type pending :: %{reference() => atom()}
    @type status ::
            {:pending_storage, pending :: pending()}
            | {:pending_storage, {pending :: pending(), continue :: term()}}
            | :idle
    @type event ::
            {:call, from :: GenServer.from(), msg :: term()}
            | {:cast, msg :: term()}
            | {:info, msg :: term()}
    defstruct [:module, :actor_name, :buffer, :status, :storage, :state]

    @type t() :: %__MODULE__{
            module: module(),
            actor_name: Dna.Types.ActorName.t(),
            buffer: [event()],
            status: status(),
            storage: [{atom(), term()}],
            state: term()
          }
    def new(module, actor_name) do
      %__MODULE__{
        module: module,
        actor_name: actor_name,
        buffer: []
      }
    end
  end

  defp get_module(_module_id), do: __MODULE__

  def start_link({{namespace, module_id, name}, registry_name}) do
    module = get_module(module_id)

    GenServer.start_link(
      __MODULE__,
      %{namespace: namespace, module_id: module_id, name: name, module: module},
      name: registry_name
    )
  end

  def init(context) do
    status = :init_storage
    state = S.new(context.module, context.actor_name)
    {:ok, state, {:continue, status}}
  end

  def handle_continue(:init_storage, %S{actor_name: an, module: module} = s) do
    storage = module.storage()

    case storage_run(storage, fn si -> Storage.init(si, an) end) do
      {:ok, storage} ->
        {:noreply, %S{s | storage: storage}, {:continue, :init}}

      {:pending, storage, pending} ->
        {:noreply, %S{s | storage: storage, status: {:pending_storage, {pending, {:continue, :init}}}}}
    end
  end

  def handle_continue(:init, %S{actor_name: an, module: module, storage: storage} = s) do
    case module.init(an, storage) do
      {:ok, state} ->
        {:noreply, %S{s | state: state, status: :idle}}

      {:ok, state, storage_change} ->
        case storage_run(storage_change, fn si -> Storage.persist(si) end, storage) do
          {:ok, storage} ->
            {:noreply, %S{s | state: state, storage: storage, status: :idle}}

          {:pending, storage, pending} ->
            {:noreply,
             %S{s | state: state, storage: storage, status: {:pending_storage, pending}}}
        end
    end
  end

  def handle_call(msg, _from, %{module: module} = context) do
    IO.puts("call: #{inspect(context)}")
    {:noreply, context}
  end

  def handle_cast(msg, %{module: module} = context) do
    IO.puts("cast: #{inspect(context)}")
    {:noreply, context}
  end

  def handle_info({opaque, msg}, %S{storage: storage, status: {:pending_storage, %{^opaque => name}, continue}} = s) do
    %{^name => si} = storage
    pending = Map.delete(pending, opaque)
    s = case Storage.on_opaque(si) do
      {:ok, si} ->
        case Kernel.map_size(pending) do
          0 -> %S{s | storage: %{storage | ^name => si}, status: :idle}
          _ -> %S{s | storage: %{storage | ^name => si}, status: {:pending_storage, pending, continue}}
        end
        {%{storage | ^name => si}, pending}
      {:ok, si, opaque} -> {%{storage | ^name => si}, Map.put(pending, opaque, name)}
    end
    s = case pending do
      p when map_size(p) == 0 -> {:noreply, %S{s | storage: storage, status: :idle}, continue}
      _ -> {:noreply, %S{s | storage: storage, status: {:pending_storage, pending, continue}}}
    end
  end

  defp buffer(msg, %S{buffer: buffer} = s), do: %S{s | buffer: [msg | buffer]}

  defp storage_run(storage, f, merge \\ storage) do
    r =
      Enum.reduce(storage, {merge, pending}, fn {name, s}, {storage, pending} ->
        case f.(s) do
          {:ok, s} -> {%{storage | ^name => s}, pending}
          {:ok, s, opaque} -> {%{storage | ^name => s}, Map.put(pending, opaque, name)}
        end
      end)

    case r do
      {storage, pending} when map_size(pending) == 0 -> {:ok, storage}
      {storage, pending} -> {:pending, storage, pending}
    end
  end
end

defmodule Dna.Server.Actor do
  @type event :: {:call, from, msg} | {:cast, msg} | {:info, msg}
  @type reply :: {:reply, to, msg}
  def init(context) do
  end

  def handle_events(events, storage, cache) do
    {replies, state_change, cache, for_after}
  end

  def after_persist(events, cache, for_after) do
    {:done, cache}
  end
end
