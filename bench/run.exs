
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
      {"test", 0, name}
    end
  end

  def storage() do
    %{
      kv: KV.new(),
    }
  end

  def init(_actorname, _storage) do
    {:ok, %{replies: []}}
  end

  def handle_events(events, %{replies: replies} = state, %{kv: kv}) do
    {kv, replies} = Enum.reduce(events, {kv, replies}, fn event, {kv, replies} ->
        case handle(kv, event) do
          {kv, nil} -> {kv, replies}
          {kv, reply} -> {kv, [reply | replies]}
        end
    end)
    {:ok, %{state | replies: Enum.reverse(replies)}, %{kv: kv}}
  end

  def after_persist(_events, %{replies: replies} = state) do
    for {to, msg} <- replies do
      GenServer.reply(to, msg)
    end
    {:ok, %{state | replies: []}}
  end

  defp handle(kv, {:call, {:get, key}, from}) do
    {kv, {from, KV.read(kv, key)}}
  end

  defp handle(kv, {:call, {:put, key, val}, from}) do
    {KV.write(kv, key, val), {from, :ok}}
  end

  defp handle(kv, {:cast, {:put, key, val}}) do
    {KV.write(kv, key, val), nil}
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
