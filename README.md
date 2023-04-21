# Durable Named Actors (DNA)

Building block for stateful distributed applications, inspired by Cloudflares Durable Objects.
Built ontop of scylladb, using the scylla-elixir driver.

## Features
- Automatic clustering, find other nodes by querying scylladb
- Durable actors, with storage modules persiting data to scylladb
- Actors events are batched for higher throughput
- Actors are automatically started on first message, or if already running forwarded to the correct node

This project is a work in progress.
Feel free to join in the development or give suggestions!

## Example
```elixir
defmodule MyActor do
  use Dna.Actor
  alias Dna.Storage.KV

  defmodule API do
    alias Dna.Serverp
    def put(name, key, value) do
      Server.call(MyActor, actor_name(name), {:put, key, value})
    end

    def put_cast(name, key, value) do
      Server.cast(MyActor, actor_name(name), {:put, key, value})
    end

    def get(name, key) do
      Server.call(MyActor, actor_name(name), {:get, key})
    end
    defp actor_name(name) do
      # namespace, actor_id, name
      {"test", 0, name}
    end
  end

  # Return a list of storage modules this actor uses
  # Currently only KV storage module is implemented (like cloudflare DO has)
  # Other modules could be implemented for customized storage layouts (ex queues)
  def storage() do
    %{
      kv: KV.new(),
    }
  end

  # setup in-memory state for this actor, could fetch from storage to load persisted values
  def init(_actorname, _storage) do
    {:ok, %{replies: []}}
  end

  # handle :cast, :call, :info events. return {:ok, new_state, new_storage}
  # events is an list, so we can batch process events for higher throughput
  def handle_events(events, %{replies: replies} = state, %{kv: kv}) do
    {kv, replies} = Enum.reduce(events, {kv, replies}, fn event, {kv, replies} ->
        case do_event(kv, event) do
          {kv, nil} -> {kv, replies}
          {kv, reply} -> {kv, [reply | replies]}
        end
    end)
    {:ok, %{state | replies: Enum.reverse(replies)}, %{kv: kv}}
  end

  # called after mutations in handle_events have been persisted
  # can reply to callers here if we want to reply after persistence.
  def after_persist(_events, %{replies: replies} = state) do
    for {to, msg} <- replies do
      GenServer.reply(to, msg)
    end
    {:ok, %{state | replies: []}}
  end

  # Actual event handlers, that writes data to storage module
  defp do_event(kv, {:call, {:get, key}, from}) do
    {kv, {from, KV.read(kv, key)}}
  end

  defp do_event(kv, {:call, {:put, key, val}, from}) do
    {KV.write(kv, key, val), {from, :ok}}
  end

  defp do_event(kv, {:cast, {:put, key, val}}) do
    {KV.write(kv, key, val), nil}
  end
end
```

there's a simple benchmark for such an actor in the bench/ folder.

```elixir
actor_name = "#{System.system_time(:millisecond)}"
total_events = 1_000_000
put_data = 0..(total_events - 1)
{time_micro, _} = :timer.tc(fn ->
  Enum.each(put_data, fn i -> BenchActor.API.put_cast(actor_name, to_string(i), "test") end)
  :ok = BenchActor.API.put(actor_name, to_string(total_events), "test")
end)

IO.puts "Single actor put, total: #{total_events} in #{time_micro / 1_000_000} seconds"
IO.puts "Put per second: #{total_events / (time_micro / 1_000_000)}"
```
on my old system:
* Intel(R) Core(TM) i7-7700K CPU @ 4.20GHz (4 cores / 8 threads)
* 24GB RAM
* Samsung_SSD_860_EVO_500GB (!SATA!)

```
Single actor put, total: 1000000 in 2.959737 seconds
Put per second: 337867.8578535863
```

## Run benchmark
```
mix deps.get
./run-scylla.sh
mix run bench/run.exs
```

## Design

#### Cluster
- fetch & connect to all nodes listed scylladb
- update heart-beat record, to let other nodes know we're alive
- periodically check for new nodes, and connect to them
- filter out dead nodes, combination of heartbeat & server_id which contains startup timestamp.
- assumes nodes are NTP synced (or close enough)

#### Actor registration
- register actor name to a node, using scylladb LWT to ensure only one node can register a name
- other nodes can try to claim the actor name if the node that registered it is dead (heartbeat timeout)
- locally to each server, actors are launched and registered to registry & dynamic supervisor partitioned by actor name

#### Actor & actor events
- actors are started on first message, or if already running forwarded to the correct node
- actors interact with storage modules to persist data
- storage modules have access to actor name and can design their own storage layout
  - ex, KV storage module uses a single table with a partition key of actor name, and a clustering key of key
  - this allowes writes/deletes to be atomically batched and reads to be fast (scylladb shard aware)
- using multiple storage modules allows for different storage layouts, ex queues, or other data structures
- actors are considered atomic if they use a single storage module which supports atomic batch writes
  - only one actor is running at a time, as long as no node missbehaves and lives longer than the heartbeat timeout (when actor name is unlocked in case of network split)
  - In order to keep actor state consistent we can sacrifice potential unavailability in case of network split

## Installation
-- TODO --

## 
- add tests
- cleanup & refactor code
- example phoenix application using DNA
- support rebalancing actors across servers
- support draining servers
- k8s example deployment
- support multiple clusters, ie once a actor name has been registered to one cluster, requests from any cluster should forward there (multi-region)
