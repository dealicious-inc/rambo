defmodule Rambo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RamboWeb.Telemetry,
      Rambo.Repo,
      {DNSCluster, query: Application.get_env(:rambo, :dns_cluster_query) || :ignore},
      {Gnat.ConnectionSupervisor,
        %{
          name: :gnat,
          connection_settings: [
            %{host: 'localhost', port: 4222}
          ]
        }},
      {Rambo.NatsSubscriber, []},
      {Phoenix.PubSub, name: Rambo.PubSub},
      RamboWeb.Presence,
      RamboWeb.Endpoint,
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Rambo.Supervisor]
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
