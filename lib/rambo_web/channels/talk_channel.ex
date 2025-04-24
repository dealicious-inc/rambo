defmodule RamboWeb.TalkChannel do
  use Phoenix.Channel

  alias Rambo.TalkRoomService
  alias Rambo.Talk.Subscriber
  alias Rambo.Nats.JetStream
  alias Rambo.Talk.MessageService

  def join("talk:" <> room_id_str, %{"user_id" => user_id_str}, socket) do
    with {room_id, _} <- Integer.parse(room_id_str),
         {user_id, _} <- Integer.parse(user_id_str),
         {:ok, _} <- TalkRoomService.join_user(room_id, user_id) do

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

  def handle_in("new_msg", %{"user" => user_id, "message" => msg}, socket) do
    room_id = socket.assigns.room_id
    payload = %{
      "user" => user_id,
      "message" => msg,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # JetStream 발행 (subject는 talk.room.{room_id})
    JetStream.publish("talk.room.#{room_id}", Jason.encode!(payload))
    {:noreply, socket}
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

  def handle_in("read_msg", %{"message_id" => message_id}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    case MessageService.mark_as_read(room_id, user_id, message_id) do
      {_count, _} ->
        broadcast_from!(socket, "message_read", %{
          user_id: user_id,
          message_id: message_id
        })

        {:noreply, socket}

      _ ->
        push(socket, "error", %{reason: "Failed to update read message"})
        {:noreply, socket}
    end
  end
end