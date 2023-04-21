defmodule Dna.Actor do
  @type actor_name :: Dna.Types.ActorName.t()
  @type event ::
          {:call, msg :: term(), from :: GenServer.from()}
          | {:cast, msg :: term()}
          | {:info, msg :: term()}
  @type state :: term
  @type handle_result :: {:noreply, state} | {:reply, term, state}
  @type storage_instance :: term()
  @type storages :: %{atom() => storage_instance()}

  @callback storage() :: storages()
  @callback init(actor_name :: actor_name(), storages :: storages()) :: {:ok, state :: term}

  @doc """
  Callback for handling events.
  """
  @callback handle_events(events :: [event()], state :: state(), storages :: storages()) ::
              {:ok, state :: state()} | {:ok, state :: state(), changed_storages :: storages()}

  @doc """
  Callback after event storages is successfully persisted.
  Useful for side-effects that requires at most once semantics.
  ex, reply to caller after storages is persisted.
  """
  @callback after_persist(events :: [event()], state :: state()) :: {:ok, state()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Dna.Actor
    end
  end
end
