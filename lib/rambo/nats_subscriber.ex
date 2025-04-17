defmodule Rambo.NatsSubscriber do
  use GenServer
  require Logger

  def start_link(_opts) do
    Logger.info("JetStream subscriber starting #{__MODULE__}")
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    Logger.info("Initializing NATS subscriber...")
    # 잠시 대기 후 구독 시도
    Process.send_after(self(), :subscribe, 1000)
    {:ok, state}
  end

  def handle_info(:subscribe, state) do
    case Jetstream.subscribe(:jetstream, self(), "chat.room.lobby",
             durable_name: "chat_room_lobby",
             deliver_policy: :all,
             ack_policy: :explicit
           ) do
      {:ok, subscription} ->
        Logger.info("✅ JetStream PushConsumer 구독 완료: chat.room.lobby")
        {:noreply, Map.put(state, :subscription, subscription)}

      error ->
        Logger.error("❌ JetStream subscribe 실패: #{inspect(error)}")
        Process.send_after(self(), :subscribe, 2000)
        {:noreply, state}
    end
  end

  def handle_info({:msg, msg}, state) do
    Logger.debug("📥 JetStream 메시지 수신: #{msg.body}")

    case Jason.decode(msg.body) do
      {:ok, payload} ->
        RamboWeb.Endpoint.broadcast!("room:lobby", "new:msg", payload)
        Jetstream.ack(msg)
      {:error, _} ->
        Logger.error("❌ 메시지 디코딩 실패")
    end

    {:noreply, state}
  end
end
