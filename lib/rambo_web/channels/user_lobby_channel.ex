defmodule RamboWeb.UserLobbyChannel do
  use Phoenix.Channel
  require Logger
  alias Rambo.TalkRoomService

  def join("user_lobby:" <> user_id_str, _params, socket) do
    case Integer.parse(user_id_str) do
      {user_id, _} ->
        socket = assign(socket, :user_id, user_id)
        # ✅ 유저 개인 NATS 채널 구독 (예: 초대받은 경우 실시간 반영)
        Rambo.Nats.JetStream.subscribe("talk.user.#{user_id}", fn _msg ->
          send(self(), :after_join)
        end)

        # ✅ 현재 유저가 참여 중인 채팅방을 구독 → 초대 등 이벤트를 실시간으로 받기 위함
        rooms = TalkRoomService.participate_list(user_id)
        Enum.each(rooms, fn room ->
          Rambo.Talk.Subscriber.subscribe_room_for_lobby(room.id, self())
        end)

        send(self(), :after_join)  # 기존 방 목록 push
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
      |> Enum.sort_by(& &1.last_activity_at || DateTime.from_unix!(0), {:desc, DateTime})
      |> Enum.map(fn room ->
        %{
          id: room.id,
          name: room.name,
          unread_count: room.unread_count || 0,
          last_read_key: room.last_read_message_key,
        }
      end)

    push(socket, "room_list", %{rooms: rooms})
    {:noreply, socket}
  end

  # 메시지를 수신했을 때 방 목록을 다시 push
  # 안읽은 카운트 읽어주기
  # after_join
  def handle_info({:msg, %{body: body}}, socket) do
    case Jason.decode(body) do
      {:ok, %{"pk" => _room_ddb_id}} ->
        Logger.info("📩 NATS message received → refreshing room list")
        send(self(), :after_join)

      {:ok, %{"type" => "invitation", "room_id" => _, "to_user_id" => user_id}} ->
        if socket.assigns.user_id == user_id do
          Logger.info("📨 초대 메시지 수신 → 방 목록 갱신")
          send(self(), :after_join)
        end

      _ ->
        IO.puts("❌ Invalid or malformed NATS body: #{inspect(body)}")
    end

    {:noreply, socket}
  end

  def handle_info({:refresh_room_list}, socket) do
    IO.puts("🔄 refresh_room_list received")
    send(self(), :after_join)
    {:noreply, socket}
  end

end
