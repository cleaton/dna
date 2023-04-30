defmodule PhoenixIotWeb.Index do
  use PhoenixIotWeb, :controller

  def default_city(conn, _) do
    redirect(conn, to: ~p"/city/Paris, France")
  end
end
