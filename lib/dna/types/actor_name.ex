defmodule Dna.Types.ActorName do
  defstruct [:module_id, :namespace, :name]
  @type t() :: %__MODULE__{
          module_id: integer(),
          namespace: String.t(),
          name: String.t()
        }
end
