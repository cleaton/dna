defmodule PhoenixIot.PubSub do
  alias Phoenix.PubSub
  def broadcast(topic, msg) do
    PubSub.broadcast(__MODULE__, topic, msg)
  end
  def subscribe(topic) do
    PubSub.subscribe(__MODULE__, topic)
  end
end
