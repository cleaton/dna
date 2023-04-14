defprotocol Dna.Storage do
  @spec init(t, actor_name) :: {:ok, t} | {:ok, t, opaque :: term}
  def init(t, actor_name)
  @spec persist(t) :: {:ok, t} | {:ok, t, opaque :: term}
  def persist(t)
  @spec on_opaque(t, opaque :: term) :: {:ok, t} | {:ok, t, opaque :: term}
  def on_opaque(t, opaque)
end
