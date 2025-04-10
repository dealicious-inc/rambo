defmodule Rambo.NatsSubscriber do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # NATS 토픽 "chat.messages" 구독 (예시)
    {:ok, _sid} = Gnat.sub(:gnat_conn, self(), "chat.messages")
    {:ok, state}
  end

  # NATS에서 메시지 수신 시 handle_info 발생
  def handle_info({:msg, %{topic: "chat.messages", body: body}}, state) do
    IO.puts("받은 메시지: #{inspect(body)}")
    {:noreply, state}
  end
end
