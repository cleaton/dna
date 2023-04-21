defprotocol Dna.Storage do
  @type actor_name :: Dna.Types.ActorName.t()
  @spec init(t, actor_name) :: {:sync, t} | {:async, t, opaque :: term}
  def init(t, actor_name)
  @spec persist(t) :: {:sync, t} | {:async, t, opaque :: term}
  def persist(t)
  @spec on_opaque(t, opaque :: term, msg :: term) :: {:sync, t} | {:async, t, opaque :: term}
  def on_opaque(t, opaque, msg)
end
