defmodule Dna.Server.Request do
  defstruct [:type, :module_id, :namespace, :name, :msg, :remote, :try]

  @type t() :: %__MODULE__{
          type: :call | :cast,
          module_id: integer(),
          namespace: String.t(),
          name: String.t(),
          msg: term(),
          remote: boolean(),
          try: integer()
        }

  def key(%__MODULE__{module_id: module_id, namespace: namespace, name: name}) do
    {module_id, namespace, name}
  end

  def remote(%__MODULE__{} = r), do: %__MODULE__{r | remote: true}
  def retry(%__MODULE__{try: count} = r), do: %__MODULE__{r | try: count + 1}
end
