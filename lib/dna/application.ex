defmodule Dna.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do

    children = [
      {Dna.DB, []},
      {Dna.Server.Cluster, []},
      {Dna.Server, []},
    ]

    opts = [strategy: :one_for_all, name: Dna.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
