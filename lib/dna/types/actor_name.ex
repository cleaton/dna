defmodule Dna.Types.ActorName do
  defstruct [:module_id, :namespace, :name]
  @type t() :: %__MODULE__{
          module_id: integer(),
          namespace: String.t(),
          name: String.t()
        }
  @spec new(String.t(), integer(), String.t()) :: Dna.Types.ActorName.t()
  def new(namespace, module_id, name) do
    %__MODULE__{namespace: namespace, module_id: module_id, name: name}
  end
  @spec new({String.t(), integer(), String.t()}) :: Dna.Types.ActorName.t()
  def new({namespace, module_id, name}) do
    %__MODULE__{namespace: namespace, module_id: module_id, name: name}
  end
  @spec as_tuple(Dna.Types.ActorName.t()) :: {String.t(), integer(), String.t()}
  def as_tuple(%__MODULE__{namespace: namespace, module_id: module_id, name: name}) do
    {namespace, module_id, name}
  end
end
