defmodule RamboWeb.TalkChannel do
  use Phoenix.Channel

  alias Rambo.TalkRoomService
  alias Rambo.Talk.Subscriber
  alias Rambo.Redis.RedisMessageStore
  alias Rambo.Ddb.DynamoDbService

  require Logger

  def join("talk:" <> room_id_str, %{"user_id" => user_id_str}, socket) do
    with {room_id, _} <- Integer.parse(room_id_str),
         user_id = String.to_integer("#{user_id_str}"),
         {:ok, _} <- TalkRoomService.join_user(room_id, user_id),
         {:ok, latest_key} <- TalkRoomService.get_latest_message_id(room_id),
         _ <- TalkRoomService.mark_as_read(room_id, user_id, latest_key) do

      Subscriber.subscribe_room(room_id)

      socket =
        socket
        |> assign(:room_id, room_id)
        |> assign(:user_id, user_id)

      IO.puts("User #{user_id} joined room #{room_id}")
      {:ok, socket}
    else
      _ -> {:error, %{reason: "invalid room or user"}}
    end
  end


  def handle_in("new_msg", %{"user" => user_id, "message" => message}, socket) do
    room_id = socket.assigns.room_id
    timestamp = System.system_time(:millisecond)

    Logger.info("톡채널 #{room_id}")
    with {:ok, room} <- Rambo.TalkRoomService.get_room_by_id(room_id) do
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

end
