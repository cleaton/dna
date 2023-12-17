defmodule Dna.DB.Nodes do
  alias ExScylla.Session
  use Dna.DB

  @node_table """
    CREATE TABLE IF NOT EXISTS nodes (
      cluster text,
      created_at timestamp,
      id bigint,
      node text,
      heartbeat bigint,
      load float,
      draining boolean,
      PRIMARY KEY ((cluster), created_at, id)
  ) WITH compaction = { 'class' : 'LeveledCompactionStrategy' };
  """

  @statements [
    node_update:
      "INSERT INTO nodes (cluster, created_at, id, node, heartbeat, load, draining) VALUES (?, ?, ?, ?, ?, ?, ?);",
    node_query:
      "SELECT created_at, id, node, heartbeat, load, draining FROM nodes WHERE cluster = ?;",
    node_delete:
      "DELETE FROM nodes WHERE cluster = ? AND created_at = ? AND id = ?;"
  ]
  @impl true
  def setup(session) do
    Session.query(session, @node_table, [])
    statements = setup_statements(session, @statements)
    {:ok, Map.merge(statements, %{session: session})}
  end

  def add(cluster, {created_at, id}, node, heartbeat, load, draining) do
    %{
      session: session,
      node_update: nu
    } = state()

    {:ok, _} =
      Session.execute(session, nu,
        text: cluster,
        timestamp: created_at,
        big_int: id,
        text: node,
        big_int: heartbeat,
        float: load,
        boolean: draining
      )

    :ok
  end

  def delete(cluster, {created_at, id}) do
    %{
      session: session,
      node_delete: nd
    } = state()

    Task.start(fn ->
      Session.execute(session, nd,
          text: cluster,
          timestamp: created_at,
          big_int: id
        )
    end)
  end

  def list(cluster) do
    %{
      session: session,
      node_query: nq
    } = state()

    {:ok, %{rows: rows}} = Session.execute(session, nq, text: cluster)

    rows
    |> Enum.map(fn %{
                     columns: [
                       timestamp: ts,
                       big_int: id,
                       text: node,
                       big_int: heatbeat,
                       float: load,
                       boolean: draining
                     ]
                   } ->
      {{ts, id}, String.to_atom(node), heatbeat, load, draining}
    end)
  end
end
