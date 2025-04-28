defmodule RamboWeb.Api.TalkRoomController do
  use RamboWeb, :controller

  alias Rambo.TalkRoomService

  # 채팅방 생성
  def create(conn, %{"name" => name, "room_type" => room_type}) do
    case TalkRoomService.create_room(%{room_type: room_type, name: name}) do
      {:ok, room} ->
        json(conn, %{room_id: room.id, name: room.name})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: changeset_errors(changeset)})
    end
  end

  # 채팅방 참여
  def join(conn, %{"id" => room_id, "user_id" => user_id}) do
    rid = if is_binary(room_id), do: String.to_integer(room_id), else: room_id
    uid = if is_binary(user_id), do: String.to_integer(user_id), else: user_id

    case TalkRoomService.join_user(rid, uid) do
      {:ok, _} -> json(conn, %{message: "joined"})
      _ -> conn |> put_status(:bad_request) |> json(%{error: "Join failed"})
    end
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  def list(conn, %{"user_id" => user_id_str}) do
    {user_id, _} = Integer.parse(user_id_str)

    rooms = Rambo.TalkRoomService.list_user_rooms_with_unread(user_id)

    json(conn, rooms)
  end

  def send_message(conn, %{"id" => room_id, "sender_id" => sender_id, "message" => message}) do
    with {rid, _} <- Integer.parse(room_id),
         sid when is_integer(sid) <- sender_id,
         {:ok, item} <- Rambo.Talk.MessageStore.store_message(%{
           room_id: "#{rid}",
           sender_id: sid,
           message: message
         }),
         :ok <- Rambo.Nats.JetStream.publish("talk.room.#{rid}", Jason.encode!(item)) do
      json(conn, %{result: "stored", item: item})
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "Failed to store or publish message"})
    end
  end

  def messages(conn, %{"id" => room_id} = params) do
    limit = Map.get(params, "limit", "20") |> String.to_integer()
    last_seen_key = Map.get(params, "last_seen_key")

    opts =
      [limit: limit] ++
      if last_seen_key, do: [last_seen_key: last_seen_key], else: []

    case Rambo.Talk.MessageService.fetch_recent_messages(room_id, opts) do
      {:ok, messages, last_key} ->
        json(conn, %{messages: messages, last_key: last_key})

      {:ok, messages} ->
        json(conn, %{messages: messages})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end

end