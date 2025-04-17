defmodule Rambo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Jetstream.API.{Consumer,Stream}

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
      {Jetstream.Supervisor, connection_name: :gnat, name: :jetstream},
      {Rambo.NatsSubscriber, []},
      {Phoenix.PubSub, name: Rambo.PubSub},
      RamboWeb.Presence,
      RamboWeb.Endpoint,
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Rambo.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # JetStream 스트림 등록
    create_chat_stream()
    {:ok, pid}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RamboWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp create_chat_stream do
    case Jetstream.API.stream_info(:jetstream, "chat") do
      {:ok, _} ->
        Logger.info("✅ chat 스트림 이미 존재함")
        :ok

      {:error, _} ->
        Logger.info("🛠️ chat 스트림 생성 시도 중")
        Jetstream.API.add_stream(:jetstream, %{
          name: "chat",
          subjects: ["chat.room.*"],
          retention: :limits,
          max_msgs: 10000,
          max_bytes: 1024 * 1024 * 50,
          storage: :memory
        })
    end
  end
end
