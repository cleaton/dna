defmodule PhoenixIot.Actors.City do
  use Dna.Actor
  alias Dna.Storage.KV
  alias PhoenixIot.PubSub

  defmodule Attraction do
    defstruct [:id, :name, :cap, :current]
    @type t() :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            cap: pos_integer(),
            current: pos_integer()
          }
    def new(name, cap, current) do
      id = to_string(System.system_time(:millisecond)) <> "-" <> to_string(:rand.uniform(100000))
      new(id, name, cap, current)
    end
    def new(id, name, cap, current) do
      %__MODULE__{id: id, name: name, cap: cap, current: current}
    end

    def to_map(%__MODULE__{id: id, name: name, cap: cap, current: current}) do
      %{
        "id" => id,
        "name" => name,
        "cap" => cap,
        "current" => current
      }
    end
    def from_json(string) do
      %{
        "id" => id,
        "name" => name,
        "cap" => cap,
        "current" => current
      } = Jason.decode!(string)
      %__MODULE__{id: id, name: name, cap: cap, current: current}
    end
    def validate(%__MODULE__{name: name, cap: cap, current: current}) do
      cond do
        cap < 0 -> {:error, "Capacity has to be over 0"}
        current < 0 -> {:error, "Current has to be over 0"}
        String.length(name) < 5 -> {:error, "Attraction name has to be at least 5 characters"}
        true -> :ok
      end
    end
  end

  defmodule API do
    alias Dna.Types.ActorName
    alias Dna.Server
    alias PhoenixIot.Actors.City
    alias PhoenixIot.Actors.City.Attraction
    @actor_id 0

    def get_status(city) do
      Server.call(City, actor_name(city), :get_status)
    end

    @spec delete_attraction(city :: String.t(), String.t()) :: :ok
    def delete_attraction(city, attraction_id) do
      Server.call(City, actor_name(city), {:delete_attraction, attraction_id})
    end

    @spec put_attraction(city :: String.t(), Attraction.t()) ::
            :ok | {:error, String.t()}
    def put_attraction(city, attraction) do
      Server.call(City, actor_name(city), {:put_attraction, attraction})
    end

    @spec list_attractions(city :: String.t()) :: list()
    def list_attractions(city) do
      kv = KV.new(actor_name(city))
      # Query storage directly is  eventually consistent, which is fine for our listing
      KV.list(kv, "a_") |> Enum.map(fn {_, json} -> Attraction.from_json(json) end)
    end

    def subscribe_attractions(city) do
      PubSub.subscribe(city)
    end

    # Generate a unique actor name
    defp actor_name(city) do
      # namespace, actor_id, name
      ActorName.new("g", @actor_id, city)
    end
  end

  # Define the storage modules used by the actor
  def storage() do
    %{
      kv: KV.new()
    }
  end

  # Initialize in-memory state for the actor
  def init(actorname, storage) do
    attractions = KV.list(storage.kv, "a_")
    status = %{
      fly_region: Application.get_env(:phoenix_iot, PhoenixIotWeb.Endpoint)[:fly_region],
      fly_alloc_id: Application.get_env(:phoenix_iot, PhoenixIotWeb.Endpoint)[:fly_alloc_id],
      started: DateTime.utc_now() |> DateTime.to_string()
    }
    {:ok, %{replies: [], actorname: actorname, count: length(attractions), status: status}}
  end

  # handle :cast, :call, :info events. return {:ok, new_state, new_storage}
  # Process events in batches for higher throughput
  def handle_events(events, %{replies: replies} = state, %{kv: kv}) do
    {kv, replies, state} =
      Enum.reduce(events, {kv, replies, state}, fn event, {kv, replies, state} ->
        case do_event(kv, event, state) do
          {kv, nil, state} -> {kv, replies, state}
          {kv, reply, state} -> {kv, [reply | replies], state}
        end
      end)
    {:ok, %{state | replies: Enum.reverse(replies)}, %{kv: kv}}
  end

  # Perform operations after event mutations have been persisted
  def after_persist(_events, %{replies: replies} = state) do
    for {to, msg, broadcast_msg} <- replies do
      GenServer.reply(to, msg)
      broadcast(state.actorname.name, broadcast_msg)
    end

    {:ok, %{state | replies: []}}
  end

  # Implement event handlers for data storage operations
  defp do_event(kv, {:call, {:put_attraction, attraction} = msg, from}, %{count: count} = state) do
    key = "a_#{attraction.id}"
    attraction = Attraction.to_map(attraction)

    case KV.read(kv, key) do
      {:ok, _} ->
        # UPDATE
        json = Jason.encode!(attraction)
        kv = KV.write(kv, key, json)
        {kv, {from, :ok, {msg, count}}, state}

      {:error, :not_found} when count < 10 ->
        # INSERT
        json = Jason.encode!(attraction)
        kv = KV.write(kv, key, json)
        count = count + 1
        {kv, {from, :ok, {msg, count}}, %{state | count: count}}

      {:error, :not_found} ->
        # FULL
        {kv, {from, {:error, "Too Many attractions"}, nil}, state}
    end
  end

  defp do_event(kv, {:call, {:delete_attraction, id} = msg, from}, %{count: count} = state) do
    key = "a_#{id}"

    case KV.read(kv, key) do
      {:ok, _} ->
        # DELETE
        kv = KV.delete(kv, key)
        count = count - 1
        {kv, {from, :ok, {msg, count}}, %{state | count: count}}

      {:error, :not_found} ->
        # NOT FOUND
        {kv, {from, :ok, nil}, state}
    end
  end

  defp do_event(kv, {:call, :get_status, from}, %{status: status} = state) do
    {kv, {from, status, nil}, state}
  end

  defp broadcast(_city, nil), do: :ok

  defp broadcast(city, msg) do
    PubSub.broadcast(city, msg)
  end
end
