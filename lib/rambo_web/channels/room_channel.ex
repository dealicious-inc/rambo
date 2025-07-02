defmodule RamboWeb.RoomChannel do
  use Phoenix.Channel

  require Logger
  @expire_seconds 3600

  def join("room:" <> room_id, %{"user_id" => user_id, "user_name" => user_name}, socket) do
    room_id = String.to_integer(room_id)
    user_id = String.to_integer("#{user_id}")
    Rambo.Nats.RoomSubscriber.subscribe_user_count(room_id)

    system_msg = %{
      "type" => "enter",
      "user_id" => user_id,
      "user_name" => user_name,
      "message" => "#{user_name}님이 입장하셨습니다",
      "system" => true
    }

    Rambo.Nats.publish("#{room_id}", system_msg)

    socket =
      socket
      |> assign(:room_id, room_id)
      |> assign(:user_id, user_id)
      |> assign(:user_name, user_name)

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

  def handle_info({:msg, %{topic: topic, body: body}}, socket) do
    cond do
      # 1. 사용자 수 업데이트 (예: room.3.count_updated)
      String.starts_with?(topic, "room.") and String.ends_with?(topic, ".count_updated") ->
        case Jason.decode(body) do
          {:ok, %{"count" => count}} ->
            push(socket, "user_count", %{count: count})
          _ ->
            IO.puts("❌ [RoomChannel] Invalid user_count payload: #{body}")
        end

      # 2. 입장/퇴장/일반 메시지 처리
      true ->
        case Jason.decode(body) do
          {:ok, %{"message" => _msg, "user_id" => _uid, "user_name" => _uname} = payload} ->
            event = Map.get(payload, "system", false) && "system_msg" || "receive_live_msg"
            push(socket, event, payload)

          _ ->
            IO.puts("❌ [RoomChannel] Invalid chat payload: #{body}")
        end
    end

    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id
    user_name = socket.assigns.user_name

    remove_user_from_redis(room_id, user_id)
    publish_user_count(room_id)

    if room_id do
      system_msg = %{
        "type" => "leave",
        "user_id" => user_id,
        "user_name" => user_name,
        "message" => "#{user_name}님이 퇴장하셨습니다",
        "system" => true
      }

      Rambo.Nats.publish("#{room_id}", system_msg)
    end

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