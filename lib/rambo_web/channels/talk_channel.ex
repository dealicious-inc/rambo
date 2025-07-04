defmodule RamboWeb.TalkChannel do
  use Phoenix.Channel

  alias Rambo.TalkRoomService
  alias Rambo.Redis.RedisMessageStore
  alias Rambo.Ddb.DynamoDbService
  alias RamboWeb.Presence

  require Logger

  def join("talk:" <> room_id, %{"user_id" => user_id}, socket) do
    Logger.info("웹소켓 톡 조인 이벤트 수신 room_id: #{room_id}, user_id: #{user_id}")

    case TalkRoomService.join_talk(room_id, user_id) do
      {:ok, _room} ->
        # Presence 트래킹
        send(self(), :after_join)

        {:ok,
          socket
          |> assign(:room_id, room_id)
          |> assign(:user_id, user_id)}

      {:error, reason} ->
        Logger.error("채팅방 조인 실패: #{inspect(reason)}")
        {:error, %{reason: reason}}
    end
  end

  def handle_info(:after_join, socket) do
    broadcast! socket, "user:entered", %{user: socket.assigns.user_id, body: "#{socket.assigns.user_id} 두둥 등장!"}

    Logger.debug ">> join #{inspect socket}"
    {:ok, _} =
      Presence.track(socket, socket.assigns.room_id, %{
        online_at: inspect(System.system_time(:second))
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in("new_msg", %{"user" => user_id, "message" => message}, socket) do
    room_id = socket.assigns.room_id
    timestamp = System.system_time(:millisecond)

    Logger.info("톡채널 #{room_id}")
    with {:ok, room} <- Rambo.TalkRoom.get(room_id) do
      {:ok, max_sequence} = RedisMessageStore.get_room_max_sequence(room_id)

      Logger.info("max_sequence: #{max_sequence}")
      # ddb insert
         item = %{
          room_id: room_id,
          timestamp: timestamp,
          sender_id: user_id,
          content: message,
          name: room.name,
          sequence: max_sequence + 1
        }
        {:ok, item} = case Rambo.Talk.MessageStore.store_message(item) do
          {:ok, item} ->
            RedisMessageStore.update_room_max_sequence(room_id)
            RedisMessageStore.update_user_last_read(room_id, user_id, item["message_id"])
            {:ok, item}
          error ->
            Logger.error("❌ Failed to store message: #{inspect(error)}")
            error
        end

      case Rambo.Nats.JetStream.publish("talk.room.#{room_id}", Jason.encode!(item)) do
        :ok ->
          Logger.info("NATS 전송 성공")
          {:reply, :ok, socket}  # 성공 시 응답
        {:error, err} ->
          IO.inspect(err, label: "❌ Failed to publish to NATS")
          push(socket, "error", %{error: "Message stored but publish failed"})
          {:noreply, socket}  # 에러 시 응답
      end
    else
      error ->
        IO.inspect(error, label: "❌ Failed to store message or update activity")
        push(socket, "error", %{error: "Message sending failed"})
        {:noreply, socket}
    end
  end

  # 읽음처리
  def handle_in("mark_read", %{"last_read_key" => key}, socket) do
    TalkRoomService.mark_as_read(socket.assigns.room_id, socket.assigns.user_id, key)
    {:noreply, socket}
  end

  # 채팅방 진입 시 메시지 가져올 때
  def handle_in("fetch_messages", _payload, socket) do
    room_id = socket.assigns.room_id

    case DynamoDbService.get_messages(room_id) do
      {:ok, messages} ->
        push(socket, "messages", %{messages: messages})
        {:noreply, socket}

      _ ->
        push(socket, "messages", %{messages: []})
        {:noreply, socket}
    end
  end

  # 이벤트를 수신했을 때 호출되는 콜백
  def handle_info({:msg, %{body: body}}, socket) do
    case Jason.decode(body) do
      {:ok, %{"message_id" => mid, "sender_id" => sid} = payload} ->
        push(socket, "new_msg", payload)

        # 본인이 보낸 메시지가 아니면 읽음 처리
        if sid != socket.assigns.user_id do
          TalkRoomService.mark_as_read(
            socket.assigns.room_id,
            socket.assigns.user_id,
            mid
          )
        end

      _ ->
        IO.puts("❌ 잘못된 메시지 포맷")
    end

    {:noreply, socket}
  end

  defp notify_user_joined(room_id, user_id) do
    payload = %{
      type: "system",
      event: "user_joined",
      room_id: room_id,
      user_id: user_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Rambo.Nats.JetStream.publish("talk.room.#{room_id}", Jason.encode!(payload))
  end

end
