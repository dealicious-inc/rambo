defmodule RamboWeb.TalkChannel do
  use Phoenix.Channel

  alias Rambo.TalkRoomService
  alias Rambo.Talk.Subscriber
  alias Rambo.Nats.JetStream
  alias Rambo.Talk.MessageService

  def join("talk:" <> room_id_str, %{"user_id" => user_id_str}, socket) do
    with {room_id, _} <- Integer.parse(room_id_str),
         user_id = String.to_integer("#{user_id_str}"),
         {:ok, _} <- TalkRoomService.join_user(room_id, user_id) do
      IO.puts("🟢")
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
         :ok <- Rambo.Nats.JetStream.publish("talk.room.#{room_id}", Jason.encode!(item)) do

      {:noreply, socket}
    else
      error ->
        IO.inspect(error, label: "❌ Failed to store/publish message")
        push(socket, "error", %{error: "Message sending failed"})
        {:noreply, socket}
    end
  end

  def handle_in("fetch_messages", payload, socket) do
    room_id = socket.assigns.room_id

    opts =
      payload
      |> Map.take(["limit", "last_seen_key"])
      |> Enum.map(fn
        {"limit", v} -> {:limit, v}
        {"last_seen_key", v} -> {:last_seen_key, v}
      end)

    case MessageService.fetch_recent_messages("#{room_id}", opts) do
      {:ok, messages, last_key} ->
        push(socket, "messages", %{messages: messages, last_key: last_key})
        {:noreply, socket}

      {:ok, messages} ->
        push(socket, "messages", %{messages: messages})
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "error", %{reason: inspect(reason)})
        {:noreply, socket}
    end
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

  def handle_info({:msg, %{body: body}}, socket) do
    case Jason.decode(body) do
      {:ok, payload = %{"message" => _, "sender_id" => _}} ->
        IO.puts(body)
        push(socket, "new_msg", payload)

      _ ->
        IO.puts("❌ Invalid NATS payload: #{inspect(body)}")
    end

    {:noreply, socket}
  end
end