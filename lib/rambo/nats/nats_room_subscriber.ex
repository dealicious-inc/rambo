defmodule Rambo.Nats.RoomSubscriber do
  use GenServer

  def start_link(room_id) do
    IO.inspect({:start_link, room_id}, label: "RoomSubscriber")
    GenServer.start_link(__MODULE__, room_id, name: via_tuple(room_id))
  end

  defp via_tuple(room_id) do
    {:via, Registry, {Rambo.Nats.RoomRegistry, to_string(room_id)}}
  end

  def init(room_id) do
    topic = "#{room_id}"

    IO.inspect({:init, topic}, label: "RoomSubscriber")

    # 구독 + listen 등록
    {:ok, subscription_pid} = Rambo.Nats.subscribe_and_listen(self(), topic)

    IO.inspect({:subscribed, topic, subscription_pid}, label: "RoomSubscriber")

    {:ok, %{room_id: room_id, topic: topic, subscription_pid: subscription_pid}}
  end

  def handle_info({:msg, %{topic: full_topic, body: body}}, state) do
    case Jason.decode(body) do
      {:ok, %{"message" => msg, "user" => user} = payload} ->
        IO.inspect({:received, full_topic, payload}, label: "RoomSubscriber")

        # broadcast 추가!
        room = state.room_id |> to_string()
        RamboWeb.Endpoint.broadcast("room:" <> room, "new_msg", payload)

      _ ->
        IO.puts("Received invalid JSON message: #{inspect(body)}")
    end

    {:noreply, state}
  end
end