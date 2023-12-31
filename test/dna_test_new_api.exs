defmodule DnaTestNewApi do
  use ExUnit.Case

  defmodule TestActor do
    use Dna.Actor
    alias Dna.Storage.KV

    defmodule API do
      alias Dna.Server

      def put(name, key, value) do
        actor_name = {"test-new-api", 0, name}
        Server.call(DnaTestNewApi.TestActor, actor_name, {:put, key, value})
      end

      def get(name, key) do
        actor_name = {"test-new-api", 0, name}
        Server.call(DnaTestNewApi.TestActor, actor_name, {:get, key})
      end
    end

    def storage() do
      %{
        kv: KV.new()
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
  end

  test "greets the world" do
    actor_name = "#{System.system_time(:millisecond)}"
    TestActor.API.put(actor_name, "hello", "world")
    assert TestActor.API.get(actor_name, "hello") == {:ok, "world"}
  end
end
