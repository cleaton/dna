defmodule Dna.Actor do
  @type actor_name :: Dna.Types.ActorName.t()
  @type state :: term()
  @type storage_instance :: term()
  @type storages :: %{atom() => storage_instance()}
  @type cast_return ::
          {:noreply, new_state :: term()} | {:noreply, new_state :: term(), storages()}
  @type call_return ::
          cast_return()
          | {:reply, msg :: term(), new_state :: term()}
          | {:reply_sync, msg :: term(), new_state :: term(), storages()}
          | {:reply_async, msg :: term(), new_state :: term(), storages()}

  @type event ::
          {:call, msg :: term(), from :: GenServer.from()}
          | {:cast, msg :: term()}
          | {:info, msg :: term()}

  @type handle_result :: {:noreply, state} | {:reply, term, state}

  @callback storage() :: storages()

  @callback init(actor_name :: actor_name(), storages :: storages()) :: {:ok, state :: term}

  @doc """
  Callback for handling all event types.
  """
  @callback handle_events(events :: [event()], state :: state(), storages :: storages()) ::
              {:ok, state :: state()}
              | {:ok, state :: state(), changed_storages :: storages()}
              | {:ok, state :: state(), changed_storages :: storages(),
                 sync_replies :: list({Genserver.from(), msg :: term()})}

  @doc """
  Handle cast message.
  """
  @callback handle_cast(request :: term(), state :: state(), storages :: storages()) ::
              cast_return()

  @doc """
  Handle call message.
  {:reply_sync, term, new_state} will reply to caller after event storages is successfully persisted.
  {:reply_async, term, new_state} will reply to caller before event storages is successfully persisted.
  """
  @callback handle_call(
              request :: term(),
              from :: GenServer.from(),
              state :: term(),
              storages :: storages()
            ) :: call_return()

  @doc """
  Callback after event storages is successfully persisted.
  Useful for side-effects that requires at most once semantics.
  ex, reply to caller after storages is persisted.
  """
  @callback after_persist(events :: [event()], state :: state()) :: {:ok, state()}

  @optional_callbacks after_persist: 2, handle_call: 4, handle_cast: 3, handle_events: 3

  defmacro __using__(_opts) do
    quote do
      @behaviour Dna.Actor
    end
  end
end
