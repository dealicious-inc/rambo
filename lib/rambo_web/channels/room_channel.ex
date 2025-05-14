  defmodule RamboWeb.RoomChannel do
    use Phoenix.Channel

    def join("room:" <> room_id, _params, socket) do
      IO.puts("Joined room: #{room_id}")
      {:ok, socket}
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
          # room 조회 실패 시 에러
          push(socket, "error", %{"reason" => "Failed to find room", "details" => inspect(reason)})
          {:noreply, socket}
      end
    end
  end