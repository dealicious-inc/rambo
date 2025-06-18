defmodule RamboWeb.RoomChannel do
  use Phoenix.Channel

  @expire_seconds 3600

  def join("room:" <> room_id, %{"user_id" => user_id}, socket) do
    room_id = String.to_integer(room_id)
    user_id = String.to_integer("#{user_id}")

    socket =
      socket
      |> assign(:room_id, room_id)
      |> assign(:user_id, user_id)

    send(self(), :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    :ok = track_user_in_redis(room_id, user_id)
    count = get_user_count(room_id)

    broadcast!(socket, "user_count", %{count: count})
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    remove_user_from_redis(room_id, user_id)
    count = get_user_count(room_id)

    broadcast!(socket, "user_count", %{count: count})
    :ok
  end

  defp track_user_in_redis(room_id, user_id) do
    key = "room:#{room_id}:users"
    Redix.command!(:redix, ["SADD", key, "#{user_id}"])
    Redix.command!(:redix, ["EXPIRE", key, "#{@expire_seconds}"])
    :ok
  end

  defp remove_user_from_redis(room_id, user_id) do
    key = "room:#{room_id}:users"
    Redix.command!(:redix, ["SREM", key, "#{user_id}"])
    :ok
  end

  defp get_user_count(room_id) do
    key = "room:#{room_id}:users"
    case Redix.command(:redix, ["SCARD", key]) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def handle_in("new_msg", %{"id" => room_id, "user" => user_id, "message" => content}, socket) do
    timestamp = DateTime.now!("Asia/Seoul") |> DateTime.truncate(:second)
    created_at = DateTime.to_iso8601(timestamp)
    message_id = "MSG##{System.system_time(:millisecond)}"

    case Rambo.Chat.ChatRoomService.get_room_by_id(room_id) do
      {:ok, room} ->
        item = %{
          "id" => room.ddb_id,
          "message_id" => message_id,
          "chat_room_id" => to_string(room_id),
          "sender_id" => to_string(user_id),
          "content" => content,
          "created_at" => created_at
        }

        case ExAws.Dynamo.put_item("messages", item) |> ExAws.request() do
          {:ok, _result} ->
            payload = %{
              "user" => user_id,
              "message" => content,
              "timestamp" => created_at
            }

            Rambo.Nats.publish("#{room_id}", payload)
            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, socket}
        end

      {:error, reason} ->
        push(socket, "error", %{"reason" => "Failed to find room", "details" => inspect(reason)})
        {:noreply, socket}
    end
  end
end
