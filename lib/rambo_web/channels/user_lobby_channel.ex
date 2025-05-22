defmodule RamboWeb.UserLobbyChannel do
  use Phoenix.Channel

  alias Rambo.TalkRoomService
  alias Rambo.Talk.MessageStore

  def join("user_lobby:" <> user_id_str, _params, socket) do
    case Integer.parse(user_id_str) do
      {user_id, _} ->
        socket = assign(socket, :user_id, user_id)

        Rambo.Nats.JetStream.subscribe("talk.room.*", self())
        send(self(), :after_join)
        {:ok, socket}

      :error ->
        {:error, %{reason: "invalid user_id"}}
    end
  end

  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id
    IO.puts("📥 after_join - userId: #{user_id}")

    rooms =
      TalkRoomService.participate_list(user_id)
      |> Enum.map(fn room ->
        %{
          id: room.id,
          name: room.name,
          unread_count: room.unread_count,
          last_read_key: Map.get(room, :last_read_message_key)
        }
      end)

    push(socket, "room_list", %{rooms: rooms})
    {:noreply, socket}
  end

  # JetStream 메시지를 수신했을 때 방 목록을 다시 push
  def handle_info({:msg, %{body: body}}, socket) do
    case Jason.decode(body) do
      {:ok, %{"id" => _room_ddb_id}} ->
        IO.puts("📩 NATS message received → refreshing room list")
        send(self(), :after_join) # 방 목록 다시 push해서 안읽음 카운트 최신화

      _ ->
        IO.puts("❌ Invalid or malformed NATS body: #{inspect(body)}")
    end

    {:noreply, socket}
  end

end
