defmodule RamboWeb.Api.RoomController do
  use RamboWeb, :controller

  def index(conn, _params) do
    rooms = Rambo.Chat.ChatRoom
            |> Rambo.Repo.all()
            |> Enum.map(&%{id: &1.id, name: &1.name})

    json(conn, rooms)
  end

  def create(conn, %{"name" => name}) do
    changeset = Rambo.Chat.ChatRoom.changeset(%Rambo.Chat.ChatRoom{}, %{name: name})

    case Rambo.Repo.insert(changeset) do
      {:ok, room} ->
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
    message_id = UUID.uuid4()

    item = %{
      "id" => message_id,
      "chat_room_id" => to_string(room_id),
      "sender_id" => to_string(user_id),
      "content" => content,
      "created_at" => created_at
    }

    case ExAws.Dynamo.put_item("messages", item) |> ExAws.request() do
      {:ok, _result} ->
        payload = %{
          user: user_id,
          message: content,
          timestamp: created_at
        }

        RamboWeb.Endpoint.broadcast("room:#{room_id}", "new_msg", payload)
        json(conn, %{status: "sent"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to save message", reason: inspect(reason)})
    end
  end
end