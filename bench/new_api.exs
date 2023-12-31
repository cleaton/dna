
defmodule BenchActor do
  use Dna.Actor
  alias Dna.Storage.KV

  defmodule API do
    alias Dna.Server
    def put(name, key, value) do
      Server.call(BenchActor, actor_name(name), {:put, key, value})
    end

    def put_cast(name, key, value) do
      Server.cast(BenchActor, actor_name(name), {:put, key, value})
    end

    def get(name, key) do
      Server.call(BenchActor, actor_name(name), {:get, key})
    end
    defp actor_name(name) do
      # namespace, actor_id, name
      {"test-new-api", 0, name}
    end
  end

  def storage() do
    %{
      kv: KV.new(),
    }
  end

  def init(_actorname, _storage) do
    {:ok, %{}}
  end

  def handle_call({:get, key}, _, state, %{kv: kv}) do
    {:reply, KV.read(kv, key), state}
  end

  def handle_call({:put, key, value}, _, state, %{kv: kv}) do
    {:reply_sync, :ok, state, %{kv: KV.write(kv, key, value)}}
  end

  def handle_cast({:put, key, value}, state, %{kv: kv}) do
    {:noreply, state, %{kv: KV.write(kv, key, value)}}
  end
end

actor_name = "#{System.system_time(:millisecond)}"
total_events = 1_000_000
put_data = 0..(total_events - 1)
{time_micro, _} = :timer.tc(fn ->
  Enum.each(put_data, fn i -> BenchActor.API.put_cast(actor_name, to_string(i), "test") end)
  :ok = BenchActor.API.put(actor_name, to_string(total_events), "test")
end)

# Print put per second
IO.puts "Single actor put, total: #{total_events} in #{time_micro / 1_000_000} seconds"
IO.puts "Put per second: #{total_events / (time_micro / 1_000_000)}"
