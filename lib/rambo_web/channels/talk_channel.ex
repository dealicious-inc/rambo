defmodule RamboWeb.TalkChannel do
  use Phoenix.Channel

  alias Rambo.TalkRoomService
  alias Rambo.Talk.Subscriber

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

    with {:ok, room} <- Rambo.TalkRoomService.get_room_by_id(room_id),
         {:ok, item} <- Rambo.Talk.MessageStore.store_message(%{
           room_id: "#{room_id}",
           sender_id: user_id,
           message: message,
           name: room.name,
           ddb_id: room.ddb_id
         }),
         :ok <- TalkRoomService.touch_activity(room_id) do

      case Rambo.Nats.JetStream.publish("talk.room.#{room_id}", Jason.encode!(item)) do
        :ok ->
          {:noreply, socket}

        err ->
          IO.inspect(err, label: "❌ Failed to publish to NATS")
          push(socket, "error", %{error: "Message stored but publish failed"})
          {:noreply, socket}
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

    case Rambo.Talk.MessageStore.get_messages(room_id) do
      {:ok, messages} ->
        push(socket, "messages", %{messages: messages})
        {:noreply, socket}

      _ ->
        push(socket, "messages", %{messages: []})
        {:noreply, socket}
    end
  end

  # 과거 메시지 더 불러오기
  def handle_in("load_more", %{"last_seen_key" => last_key}, socket) do
    room_id = socket.assigns.room_id
    IO.puts("불러옴불러옴")
    case Rambo.Talk.MessageStore.get_messages(room_id, last_seen_key: last_key) do
      {:ok, messages} ->
        push(socket, "messages:prepend", %{messages: messages})
        {:noreply, socket}

      _ ->
        push(socket, "messages:prepend", %{messages: []})
        {:noreply, socket}
    end
  end

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