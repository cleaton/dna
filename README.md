# Durable Named Actors (DNA)

DNA is an innovative building block for stateful distributed applications, taking inspiration from Cloudflare's Durable Objects. This library streamlines the development of distributed applications while offering a simple, user-friendly API for creating stateful actors.

## Key advantages
* Unique actor naming across clusters to guarantee single-instance operation
* Storage API with strong consistency and atomic writes within each actor
* In-order and batched event processing for high throughput

By reducing the boilerplate code typically associated with distributed applications. Potential use cases include distributed chat applications, where each chat room operates as an actor, or distributed game servers, with each game functioning as an actor. DNA is also ideal for creating data processing pipelines, where each stage consists of a set of actors akin to Kafka Streams partitions.

DNA is built on top of ScyllaDB, utilizing the ex_scylla driver for optimal performance.

## Notable Features
* Seamless clustering, facilitated by ScyllaDB queries
* Persistent and durable actors with storage modules for data retention
* Batching of actor events for superior throughput (refer to benchmarks)
* Automatic actor initialization on first message receipt or appropriate node forwarding if already active

Please note that this project is a work in progress. I welcome your contributions, suggestions, and collaboration.

## Example
```elixir
defmodule MyActor do
  use Dna.Actor
  alias Dna.Storage.KV

  defmodule API do
    alias Dna.Server
    # Define put, put_cast, and get functions for MyActor
    def put(name, key, value) do
      Server.call(MyActor, actor_name(name), {:put, key, value})
    end

    def put_cast(name, key, value) do
      Server.cast(MyActor, actor_name(name), {:put, key, value})
    end

    def get(name, key) do
      Server.call(MyActor, actor_name(name), {:get, key})
    end

    # Generate a unique actor name
    defp actor_name(name) do
      # namespace, actor_id, name
      {"test", 0, name}
    end
  end

  # Define the storage modules used by the actor
  def storage() do
    %{
      kv: KV.new(),
    }
  end

  # Initialize in-memory state for the actor
  def init(_actorname, _storage) do
    {:ok, %{replies: []}}
  end

  # handle :cast, :call, :info events. return {:ok, new_state, new_storage}
  # Process events in batches for higher throughput
  def handle_events(events, %{replies: replies} = state, %{kv: kv}) do
    {kv, replies} = Enum.reduce(events, {kv, replies}, fn event, {kv, replies} ->
        case do_event(kv, event) do
          {kv, nil} -> {kv, replies}
          {kv, reply} -> {kv, [reply | replies]}
        end
    end)
    {:ok, %{state | replies: Enum.reverse(replies)}, %{kv: kv}}
  end

  # Perform operations after event mutations have been persisted
  def after_persist(_events, %{replies: replies} = state) do
    for {to, msg} <- replies do
      GenServer.reply(to, msg)
    end
    {:ok, %{state | replies: []}}
  end

  # Implement event handlers for data storage operations
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

A simple benchmark for such an actor can be found in the bench/ folder.

```elixir
# Set up benchmarking parameters
actor_name = "#{System.system_time(:millisecond)}"
total_events = 1_000_000
put_data = 0..(total_events - 1)
{time_micro, _} = :timer.tc(fn ->
  Enum.each(put_data, fn i -> BenchActor.API.put_cast(actor_name, to_string(i), "test") end)
  :ok = BenchActor.API.put(actor_name, to_string(total_events), "test")
end)
# Display benchmark results
IO.puts "Single actor put, total: #{total_events} in #{time_micro / 1_000_000} seconds"
IO.puts "Put per second: #{total_events / (time_micro / 1_000_000)}"
```

### Benchmark results on the sample system:

Intel(R) Core(TM) i7-7700K CPU @ 4.20GHz (4 cores / 8 threads)
24GB RAM
Samsung SSD 860 EVO 500GB (SATA)

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

### Cluster
* Discover and connect to all nodes listed in ScyllaDB
* Update heartbeat records for live node detection
* Periodically check for new nodes and connect to them
* Filter out dead nodes based on heartbeat and server_id
* Assumes nodes have synchronized time (e.g., via NTP)

### Actor registration
* Register actor names to nodes, ensuring uniqueness with ScyllaDB LWT
* Reclaim actor names from dead nodes based on heartbeat timeout
* Launch and register actors locally on each server using partitioned dynamic supervisors

### Actor & actor events
* Initialize actors on first message or forward to the correct node if already active
* Actors interact with storage modules for data persistence
* Utilize multiple storage modules for different data structures and layouts
* Ensure atomic operation with single storage modules supporting atomic batch writes
* Maintain actor state consistency while allowing for potential unavailability during network splits

## Installation
-- TODO --

## Roadmap
* Add tests
* Refactor and clean up code
* Create an example Phoenix application using DNA
* Support actor rebalancing across servers
* Implement server draining
* Provide a Kubernetes example deployment
* Create data-processing pipeline pipeline storage module
* Support multi-region clusters for global actor registration and request forwarding
