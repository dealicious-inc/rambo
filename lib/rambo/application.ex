defmodule Rambo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
#      {
#        Gnat,
#        %{
#          name: :gnat_conn, # process이름
#          host: ~c"127.0.0.1",
#          port: 4222
#        }
#      },
      RamboWeb.Telemetry,
      Rambo.Repo,
      {DNSCluster, query: Application.get_env(:rambo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Rambo.PubSub},
      # Start a worker by calling: Rambo.Worker.start_link(arg)
      # {Rambo.Worker, arg},
      # Start to serve requests, typically the last entry
      # Rambo.NatsSubscriber,
      RamboWeb.Presence,
      RamboWeb.Endpoint,
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rambo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RamboWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
