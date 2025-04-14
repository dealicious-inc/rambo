defmodule Rambo.NatsSubscriber do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    Process.send_after(self(), :init_subscription, 500)
    {:ok, state}
  end

  # NATS에서 메시지 수신 시 handle_info 발생
  def handle_info(:init_subscription, state) do
    if Process.whereis(:gnat_conn) do
      case Gnat.sub(:gnat_conn, self(), "chat.messages") do
        {:ok, _sid} ->
          IO.puts("구독 성공!")
          {:noreply, state}
        error ->
          IO.puts("구독 실패, 재시도: #{inspect(error)}")
          Process.send_after(self(), :init_subscription, 500)
          {:noreply, state}
      end
    else
      IO.puts(":gnat_conn 미등록, 재시도...")
      Process.send_after(self(), :init_subscription, 500)
      {:noreply, state}
    end
  end

  def handle_info({:msg, %{topic: "chat.messages", body: body}}, state) do
    IO.puts("받은 메시지: #{inspect(body)}")
    {:noreply, state}
  end
end

