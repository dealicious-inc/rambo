defmodule RamboWeb.RoomChannel do
  use Phoenix.Channel

  alias Rambo.Redis.RedisMessageStore
  alias Rambo.RedisClient
  require Logger


  def join("room:" <> room_id, _params, socket) do
    IO.puts("Joined room: #{room_id}")
    {:ok, socket}
  end

  # 클라이언트 → 서버로 push한 이벤트 처리
  def handle_in("new_msg", %{"id" => room_id, "user" => user_id, "message" => content}, socket) do
    timestamp = DateTime.now!("Asia/Seoul") |> DateTime.truncate(:second)
    created_at = DateTime.to_iso8601(timestamp)
    sk = "MSG##{System.system_time(:millisecond)}"
    message_id = UUID.uuid4()  # 여기서 고유 ID 생성

    IO.puts("룸채널")
    case Rambo.Chat.ChatRoomService.get_room_by_id(room_id) do
      {:ok, room} ->
        {:ok, max_sequence} = RedisMessageStore.get_room_max_sequence(room_id)
        item = %{
          "pk" => room_id,
          "sk" => sk,
          "message_id" => message_id, # GSI
          "sender_id" => to_string(user_id),
          "content" => content,
          "timestamp" => timestamp,
          "sequence" => max_sequence.to_integer() + 1
        }
        IO.puts("#{room_id}는 몇개의 메시지가있냐면,")
        RedisClient.set("d12344d", 1000)
        Rambo.Redis.RedisMessageStore.update_room_max_sequence(room_id)

        case ExAws.Dynamo.put_item("messages", item) |> ExAws.request() do
          {:ok, _result} ->
            payload = %{
              "user" => user_id,
              "message" => content,
              "timestamp" => created_at,
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
