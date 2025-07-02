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

  def send_message(conn, %{"id" => room_id, "user_id" => user_id, "user_name" => user_name, "message" => content, "type" => type}) do
    timestamp = DateTime.now!("Asia/Seoul") |> DateTime.truncate(:second)
    created_at = DateTime.to_iso8601(timestamp)
    message_id = "MSG##{System.system_time(:millisecond)}"

    # 룸 조회
    case Rambo.Chat.ChatRoomService.get_room_by_id(room_id) do
      {:ok, room} ->
        item = %{
          "id" => room.ddb_id,
          "message_id" => message_id,
          "chat_room_id" => to_string(room_id),
          "sender_id" => to_string(user_id),
          "user_name" => user_name,
          "content" => content,
          "type" => type,
          "created_at" => created_at
        }

        # DynamoDB에 저장
        case ExAws.Dynamo.put_item("live_messages", item) |> ExAws.request() do
          {:ok, _result} ->
            payload = %{
              "user_id" => user_id,
              "user_name" => user_name,
              "message" => content,
              "type" => type,
              "timestamp" => created_at
            }

            Rambo.Nats.publish("#{room_id}", payload)

            # 성공 응답
            json(conn, %{status: "sent"})

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to save message", reason: inspect(reason)})
        end

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Room not found", reason: inspect(reason)})
    end
  end

  def participate_users(conn, %{"room_id" => room_id}) do
    key = "room:#{room_id}:users"

    case Redix.command(Rambo.Redis, ["SMEMBERS", key]) do
      {:ok, entries} ->
        users =
          entries
          |> Enum.map(fn entry ->
            case String.split(entry, "#", parts: 2) do
              [user_id_str, user_name] ->
                %{
                  user_id: String.to_integer(user_id_str),
                  user_name: user_name
                }

              _ ->
                nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        json(conn, %{room_id: room_id, users: users})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to fetch users", reason: inspect(reason)})
    end
  end

  def ban_user(conn, %{"user_id" => user_id}) do
    key = "chat:banned:#{user_id}"

    Redix.command!(Rambo.Redis, ["SET", key, "1"])
    Redix.command!(Rambo.Redis, ["EXPIRE", key, "300"])

    json(conn, %{status: "ok", message: "사용자를 5분간 차단했습니다."})
  end
end
