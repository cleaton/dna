defmodule Dna.DB.Actors do
  alias ExScylla.Session
  use Dna.DB

  @node_table """
    CREATE TABLE IF NOT EXISTS actors (
      namespace text,
      module_id int,
      name text,
      node_created timestamp,
      node_id bigint,
      claimed_at timestamp,
      PRIMARY KEY ((namespace, module_id), name)
  ) WITH compaction = { 'class' : 'LeveledCompactionStrategy' };
  """

  @statements [
    where_is:
      "SELECT node_created, node_id FROM actors WHERE namespace = ? AND module_id = ? AND name = ?;",
    add_if_not_exists:
      "INSERT INTO actors (namespace, module_id, name, node_created, node_id, claimed_at) VALUES (?, ?, ?, ?, ?, ?) IF NOT EXISTS;",
    replace_existing:
      "UPDATE actors SET node_created = ?, node_id = ?, claimed_at = ? WHERE namespace = ? AND module_id = ? AND name = ? IF node_created = ? AND node_id = ?;"
  ]
  @impl true
  def setup(session) do
    Session.query(session, @node_table, [])
    statements = setup_statements(session, @statements)
    {:ok, Map.merge(statements, %{session: session})}
  end

  def claim({namespace, module_id, name}, {server_started, server_id}, prev_server \\ nil) do
    now = System.system_time(:millisecond)

    %{
      session: session,
      add_if_not_exists: ane,
      replace_existing: re
    } = state()

    if prev_server do
      {prev_started, prev_id} = prev_server
      #UPDATE actors SET node_created = ?, node_id = ?, claimed_at = ? WHERE namespace = ? AND module_id = ? AND name = ? IF node_created = ? AND node_id = ?;"

      {:ok, %{rows: rows}} =
        Session.execute(session, re,
          timestamp: server_started,
          big_int: server_id,
          timestamp: now,
          text: namespace,
          int: module_id,
          text: name,
          timestamp: prev_started,
          big_int: prev_id
        )

      case rows do
        [%{columns: [boolean: true]}] -> :ok
        _ -> {:error, :conflict}
      end
    else
      {:ok, %{rows: rows}} =
        Session.execute(session, ane,
          text: namespace,
          int: module_id,
          text: name,
          timestamp: server_started,
          big_int: server_id,
          timestamp: now
        )

      case rows do
        [%{columns: [boolean: true]}] -> :ok
        _ -> {:error, :conflict}
      end
    end
  end

  def where_is(namespace, module_id, name) do
    %{
      session: session,
      where_is: wi
    } = state()

    {:ok, %{rows: rows}} =
      Session.execute(session, wi,
        text: namespace,
        int: module_id,
        text: name
      )

    case rows do
      [%{columns: [timestamp: ts, big_int: id]}] -> {ts, id}
      [] -> :not_found
    end
  end
end
