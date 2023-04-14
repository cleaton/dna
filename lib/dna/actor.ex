defmodule Dna.Actor do
  @type event :: term
  @type state :: term
  @type handle_result :: {:noreply, state} | {:reply, term, state}

  @callback init(args :: keyword) :: {:ok, state :: term}

  @doc """
  Callback for handling events.
  """
  @callback handle_event(event :: term, state :: term) :: {:noreply, state :: term}

  @doc """
  Callback after event state is successfully persisted.
  Useful for side-effects that requires at most once semantics.
  """
  @callback after_event(event :: term, state :: term) :: :ok

  defmacro __using__(_opts) do
    quote do
      @behaviour Dna.Actor
    end
  end
end
