# Durable Named Actors (DNA)

DNA is a powerful building block for stateful distributed applications, taking inspiration from Cloudflare's Durable Objects & Microsoft Orleans. This library streamlines the development of distributed applications while offering a simple, user-friendly API for creating stateful actors.

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

## Architecture
[See architecture doc](docs/architecture.md)

## Demo
A stateful phoenix app that uses DNA: https://dna-demo.fly.dev/
The source code for the demo can be found in `examples/phoenix_iot`

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
    {:ok, %{}}
  end

  # handle call/cast events. Internally batched for performance
  # Choose to reply to caller after storage is persisted

  # Reply immediately as no storage is mutated
  def handle_call({:get, key}, _, state, %{kv: kv}) do
    {:reply, KV.read(kv, key), state}
  end

  # Reply after storage is persisted (end of each batch, 1~100msg)
  def handle_call({:put, key, value}, _, state, %{kv: kv}) do
    {:reply_sync, :ok, state, %{kv: KV.write(kv, key, value)}}
  end

  # Storage is eventually persisted (end of each batch, 1~100msg)
  def handle_cast({:put, key, value}, state, %{kv: kv}) do
    {:noreply, state, %{kv: KV.write(kv, key, value)}}
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
* Cluster assumes that nodes have synchronized time (e.g., via NTP)

### Actor registration
* Register actor names to nodes, ensuring uniqueness with ScyllaDB LWT
* Reclaim actor names from dead nodes based on heartbeat timeout
* Launch and register actors locally on each server using partitioned dynamic supervisors

### Actor & actor events
* Initialize actors on first message or forward to the correct node if already active
* Actors interact with storage modules for data persistence
* Utilize multiple storage modules for different data structures and layouts
* Ensure atomic operation with single storage module supporting atomic batch writes
* Prioritize actor state consistency over availability in case of network splits

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
