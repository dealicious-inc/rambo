defmodule RamboWeb.Api.RoomController do
  use RamboWeb, :controller

  def index(conn, _params) do
    rooms =
      Rambo.Chat.ChatRoom
      |> Rambo.Repo.all()
      |> Enum.map(&%{id: &1.id, name: &1.name})

    json(conn, rooms)
  end

  def create(conn, %{"name" => name, "user_id" => user_id}) do
    ddb_id = "LIVE##{user_id}##{System.system_time(:second)}"

    changeset =
      Rambo.Chat.ChatRoom.changeset(%Rambo.Chat.ChatRoom{}, %{name: name, ddb_id: ddb_id})

    case Rambo.Repo.insert(changeset) do
      {:ok, room} ->
        DynamicSupervisor.start_child(
          Rambo.Nats.RoomSupervisor,
          {Rambo.Nats.RoomSubscriber, room.id}
        )

        json(conn, %{id: room.id, name: room.name, message: "Room created"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create room", reason: changeset.errors})
    end
  end

  def send_message(conn, %{"id" => room_id, "user" => user_id, "message" => content}) do
    timestamp = DateTime.now!("Asia/Seoul") |> DateTime.truncate(:second)
    created_at = DateTime.to_iso8601(timestamp)
    message_id = "MSG##{System.system_time(:millisecond)}"

    # 룸 조회
    case Rambo.Chat.ChatRoomService.get_room_by_id(room_id) do
      {:ok, room} ->
        item = %{
          "id" => room.ddb_id,  # ddb_id 사용
          "message_id" => message_id,
          "chat_room_id" => to_string(room_id),
          "sender_id" => to_string(user_id),
          "content" => content,
          "created_at" => created_at
        }

        # DynamoDB에 저장
        case ExAws.Dynamo.put_item("messages", item) |> ExAws.request() do
          {:ok, _result} ->
            # NATS에 메시지 발행
            payload = %{
              "user" => user_id,
              "message" => content,
              "timestamp" => created_at
            }

            Rambo.Nats.publish("#{room_id}", payload)

            # 성공 응답
            json(conn, %{status: "sent"})

          {:error, reason} ->
            # DynamoDB 저장 실패시 오류 처리
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to save message", reason: inspect(reason)})
        end

      {:error, reason} ->
        # 채팅방 조회 실패시 오류 처리
        conn
        |> put_status(:not_found)
        |> json(%{error: "Room not found", reason: inspect(reason)})
    end
  end
end
