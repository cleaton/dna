defmodule Dna.DB.Storage.Kv do
  alias ExScylla.Session
  alias ExScylla.Statement.Batch
  alias Dna.Types.ActorName
  use Dna.DB

  @node_table """
    CREATE TABLE IF NOT EXISTS storage_kv (
      namespace text,
      module_id int,
      name text,
      key blob,
      value blob,
      size int,
      PRIMARY KEY ((namespace, module_id, name), key)
  ) WITH compaction = { 'class' : 'LeveledCompactionStrategy' };
  """

  @statements [
    list:
      "SELECT key, value FROM storage_kv WHERE namespace = ? AND module_id = ? AND name = ? LIMIT ?;",
    list_from:
      "SELECT key, value FROM storage_kv WHERE namespace = ? AND module_id = ? AND name = ? AND key > ? LIMIT ?;",
    read:
      "SELECT value FROM storage_kv WHERE namespace = ? AND module_id = ? AND name = ? AND key = ?;",
    write:
      "INSERT INTO storage_kv (namespace, module_id, name, key, value, size) VALUES (?, ?, ?, ?, ?, ?);",
    delete:
      "DELETE FROM storage_kv WHERE namespace = ? AND module_id = ? AND name = ? AND key = ?;"
  ]
  @impl true
  def setup(session) do
    Session.query(session, @node_table, [])
    statements = setup_statements(session, @statements)
    {:ok, Map.merge(statements, %{session: session})}
  end

  def list(%ActorName{namespace: namespace, module_id: module_id, name: name}, prefix, limit) do
    limit =
      case limit do
        limit when limit > 1000 -> 1000
        limit when is_integer(limit) -> limit
        _ -> 100
      end

    %{
      session: session,
      list: list,
      list_from: list_from
    } = state()

    {ps, values} =
      case prefix do
        prefix when is_binary(prefix) ->
          {list_from, text: namespace, int: module_id, text: name, blob: prefix, int: limit}

        _ ->
          {list, text: namespace, int: module_id, text: name, int: limit}
      end

    {:ok, %{rows: rows}} = Session.execute(session, ps, values)

    rows
    |> Enum.map(fn %{columns: [blob: key, blob: value]} -> {key, value} end)
  end

  @spec read(
          Dna.Types.ActorName.t(),
          key :: String.t()
        ) :: {:error, :not_found} | {:ok, any}
  def read(%ActorName{namespace: namespace, module_id: module_id, name: name}, key) do
    %{
      session: session,
      read: read
    } = state()

    {:ok, %{rows: rows}} =
      Session.execute(session, read, text: namespace, int: module_id, text: name, blob: key)

    case rows do
      [%{columns: [blob: value]}] -> {:ok, value}
      _ -> {:error, :not_found}
    end
  end

  def mutate(%ActorName{namespace: namespace, module_id: module_id, name: name}, operations, async_opaque \\ nil) do
    %{
      session: session,
      write: write,
      delete: delete
    } = state()

    {statements, values} =
      operations
      |> Enum.reduce({[], []}, fn
        {key, nil}, {statements, values} ->
          {
            [delete | statements],
            [[text: namespace, int: module_id, text: name, blob: key] | values]
          }

        {key, value}, {statements, values} ->
          {
            [write | statements],
            [
              [
                text: namespace,
                int: module_id,
                text: name,
                blob: key,
                blob: value,
                int: byte_size(value)
              ]
              | values
            ]
          }
      end)

    batch = Batch.new_with_statements(:unlogged, statements)

    {:ok, _} =
      case async_opaque do
        nil -> Session.batch(session, batch, values)
        opaque -> Session.async_batch(session, batch, values, opaque)
      end

    :ok
  end
end
