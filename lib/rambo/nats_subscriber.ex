defmodule Rambo.NatsSubscriber do
  use GenServer
  alias Phoenix.PubSub

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(state) do
    {:ok, _sid} = Gnat.sub(:gnat_conn, self(), "room.lobby")
    {:ok, state}
  end

  # NATS에서 메시지 수신 시 handle_info 발생
  def handle_info({:msg, %{topic: "room.lobby", body: body}}, state) do
    # NATS에서 받은 메시지를 Phoenix 채널로 broadcast
    payload = Jason.decode!(body)
    RamboWeb.Endpoint.broadcast!("room:lobby", "new:msg", payload)

    {:noreply, state}
  end
end

