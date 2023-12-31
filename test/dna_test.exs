defmodule DnaTest do
  use ExUnit.Case
  doctest Dna

  defmodule TestActor do
    use Dna.Actor
    alias Dna.Storage.KV

    defmodule API do
      alias Dna.Server

      def put(name, key, value) do
        actor_name = {"test", 0, name}
        Server.call(DnaTest.TestActor, actor_name, {:put, key, value})
      end

      def get(name, key) do
        actor_name = {"test", 0, name}
        Server.call(DnaTest.TestActor, actor_name, {:get, key})
      end
    end

    def storage() do
      %{
        kv: KV.new()
      }
    end

    def init(_actorname, _storage) do
      {:ok, %{replies: []}}
    end

    def handle_events(events, %{replies: replies} = state, %{kv: kv}) do
      {kv, replies} =
        Enum.reduce(events, {kv, replies}, fn event, {kv, replies} ->
          {kv, reply} = handle(kv, event)
          {kv, [reply | replies]}
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
  end

  test "greets the world" do
    actor_name = "#{System.system_time(:millisecond)}"
    TestActor.API.put(actor_name, "hello", "world")
    assert TestActor.API.get(actor_name, "hello") == {:ok, "world"}
  end
end
