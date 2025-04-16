defmodule Rambo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ets.new(:chat_rooms, [:named_table, :set, :public])

    children = [
      RamboWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:rambo, :dns_cluster_query) || :ignore},
      {Finch, name: Rambo.Finch},
      RamboWeb.Endpoint,
      Rambo.Repo,
      %{
        id: Rambo.Nats.Connection,
        start: {Rambo.Nats.Connection, :start_link, [[]]},
        type: :worker,
        restart: :permanent,
        shutdown: 500
      },
      %{
          id: :nats_subscriber,
          start: {Rambo.Chat.NatsStarter, :start_link, [[]]}
       },
      {Phoenix.PubSub, name: Rambo.PubSub},
    ]

    opts = [strategy: :one_for_one, name: Rambo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    RamboWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

