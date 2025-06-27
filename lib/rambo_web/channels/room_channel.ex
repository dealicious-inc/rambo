defmodule RamboWeb.RoomChannel do
  use Phoenix.Channel

  require Logger
  @expire_seconds 3600

  def join("room:" <> room_id, %{"user_id" => user_id}, socket) do
    room_id = String.to_integer(room_id)
    user_id = String.to_integer("#{user_id}")
    Rambo.Nats.RoomSubscriber.subscribe_user_count(room_id)

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
    publish_user_count(room_id)

    {:noreply, socket}
  end

  def handle_info({:msg, %{topic: "room." <> _rest, body: body}}, socket) do
    case Jason.decode(body) do
      {:ok, %{"count" => count}} ->
        push(socket, "user_count", %{count: count})
      _ ->
        IO.puts("❌ [RoomChannel] Invalid user_count payload: #{body}")
    end

    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    remove_user_from_redis(room_id, user_id)
    publish_user_count(room_id)

    :ok
  end

  defp publish_user_count(room_id) do
    count = get_user_count(room_id)

    payload = %{
      "room_id" => room_id,
      "count" => count
    }

    Rambo.Nats.publish("room.#{room_id}.count_updated", payload)
  end

  defp track_user_in_redis(room_id, user_id) do
    key = "room:#{room_id}:users"
    Redix.command!(Rambo.Redis, ["SADD", key, "#{user_id}"])
    Redix.command!(Rambo.Redis, ["EXPIRE", key, "#{@expire_seconds}"])
    :ok
  end

  defp remove_user_from_redis(room_id, user_id) do
    key = "room:#{room_id}:users"
    Redix.command!(Rambo.Redis, ["SREM", key, "#{user_id}"])
    :ok
  end

  defp get_user_count(room_id) do
    key = "room:#{room_id}:users"
    case Redix.command(Rambo.Redis, ["SCARD", key]) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def handle_in("send_live_msg", %{"id" => room_id, "user_id" => user_id, "user_name" => user_name, "message" => content}, socket) do
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
          "user_name" => user_name,
          "content" => content,
          "created_at" => created_at
        }

        case ExAws.Dynamo.put_item("live_messages", item) |> ExAws.request() do
          {:ok, _result} ->
            payload = %{
              "user_id" => user_id,
              "user_name" => user_name,
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