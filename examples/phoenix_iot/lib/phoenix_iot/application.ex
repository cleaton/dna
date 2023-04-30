defmodule PhoenixIot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      PhoenixIotWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: PhoenixIot.PubSub},
      # Start the Endpoint (http/https)
      PhoenixIotWeb.Endpoint
      # Start a worker by calling: PhoenixIot.Worker.start_link(arg)
      # {PhoenixIot.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixIot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhoenixIotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
