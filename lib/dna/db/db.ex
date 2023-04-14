defmodule Dna.DB do
  alias ExScylla.Session
  defmodule Helpers do
    def setup_statements(session, statements) do
      Enum.reduce(statements, %{}, fn {name, query}, acc ->
        {:ok, ps} = Session.prepare(session, query)
        Map.put(acc, name, ps)
      end)
    end
  end

  # TODO: Use persistant_term storage instead to store session and related data?
  # https://www.erlang.org/doc/man/persistent_term.html#description
  @callback setup(session :: term) :: {:ok, new_state :: term} | {:error, reason :: term}
  defmacro __using__(_opts) do
    quote do
      @behaviour Dna.DB
      import Dna.DB.Helpers
      alias ExScylla.Session
      defp state() do
        case :ets.lookup(Dna.DB, __MODULE__) do
          [{_, state}] -> state
        end
      end
    end
  end

  alias ExScylla.SessionBuilder
  use GenServer

  defp do_ls_r(paths, result \\ [])
  defp do_ls_r([], result), do: result
  defp do_ls_r([path | rest], result) do
    case File.dir?(path) do
      true -> do_ls_r(File.ls!(path) ++ rest, result)
      false -> do_ls_r(rest, [path | result])
    end
  end


  defmacrop storage_modules() do
    do_ls_r([__ENV__.file |> Path.dirname()])
    |> tap(fn files -> IO.inspect(files) end)
    |> Enum.filter(&(!String.equivalent?(&1, "db.ex")))
    |> Enum.map(&(String.replace_suffix(&1, ".ex", "")))
    |> Enum.map(&Macro.camelize/1)
    |> Enum.map(&(Module.concat([__MODULE__, &1])))
  end

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  @impl true
  def init(_) do
    ets_table = :ets.new(__MODULE__, [:named_table, read_concurrency: true])
    session = start_session(ets_table)
    setup(ets_table, session)
    {:ok, %{session: session, ets_table: ets_table}}
  end

  defp start_session(ets_table) do
    {:ok, session} = SessionBuilder.new()
                    |> SessionBuilder.known_node("127.0.0.1:9042")
                    |> SessionBuilder.use_keyspace("dna", false)
                    |> SessionBuilder.build()
    :ets.insert(ets_table, {:session, session})
    session
  end

  defp setup(ets_table, session) do
    storage_modules()
    |> Enum.each(fn m ->
      {:ok, state} = m.setup(session)
      :ets.insert(ets_table, {m, state})
    end)
  end
end
