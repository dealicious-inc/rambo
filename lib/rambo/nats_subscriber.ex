defmodule Rambo.NatsSubscriber do
  use GenServer
  require Logger

  def start_link(_opts) do
    Logger.info("NATS subscriber starting #{__MODULE__}")
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    Logger.info("Initializing NATS subscriber...")
    # 잠시 대기 후 구독 시도
    Process.send_after(self(), :subscribe, 1000)
    {:ok, state}
  end

  def handle_info(:subscribe, state) do
    case ensure_gnat_connection(5) do
      :ok ->
        case Gnat.sub(:gnat, self(), "room.lobby") do
          {:ok, sid} ->
            Logger.info("✅ Subscribed to NATS topic: room.lobby")
            {:noreply, Map.put(state, :sid, sid)}
          error ->
            Logger.error("❌ Failed to subscribe to NATS: #{inspect(error)}")
            # 재시도
            Process.send_after(self(), :subscribe, 2000)
            {:noreply, state}
        end
      :error ->
        Logger.error("❌ NATS connection not available")
        Process.send_after(self(), :subscribe, 2000)
        {:noreply, state}
    end
  end

  defp ensure_gnat_connection(0), do: :error
  defp ensure_gnat_connection(attempts) do
    case Process.whereis(:gnat) do
      nil ->
        Logger.debug("Waiting for NATS connection... (#{attempts} attempts left)")
        Process.sleep(1000)
        ensure_gnat_connection(attempts - 1)
      _pid ->
        Logger.debug("NATS connection found")
        :ok
    end
  end

  def handle_info({:msg, %{topic: "room.lobby", body: body}}, state) do
    Logger.debug("📥 NATS message received: #{body}")

    case Jason.decode(body) do
      {:ok, payload} ->
        RamboWeb.Endpoint.broadcast!("room:lobby", "new:msg", payload)
      {:error, _} ->
        Logger.error("❌ Failed to decode NATS payload")
    end

    {:noreply, state}
  end
end