defmodule RamboWeb.Api.TalkRoomController do
  use RamboWeb, :controller

  alias Rambo.TalkRoomService

  # 그룹 채팅방 생성
  def create(conn, %{"name" => name}) do
    case TalkRoomService.create_room(%{room_type: "group", name: name}) do
      {:ok, room} ->
        json(conn, %{room_id: room.id, name: room.name})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: changeset_errors(changeset)})
    end
  end

  # 1:1 채팅방 생성 or 찾기
  def private(conn, %{"user1_id" => user1_id, "user2_id" => user2_id}) do
    with {uid1, _} <- Integer.parse(user1_id),
         {uid2, _} <- Integer.parse(user2_id),
         {:ok, room} <- TalkRoomService.find_or_create_private_room(uid1, uid2) do
      json(conn, %{room_id: room.id, name: room.name})
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "Invalid request"})
    end
  end

  # 채팅방 참여
  def join(conn, %{"id" => room_id, "user_id" => user_id}) do
    with {rid, _} <- Integer.parse(room_id),
         {uid, _} <- Integer.parse(user_id),
         {:ok, _} <- TalkRoomService.join_user(rid, uid) do
      json(conn, %{message: "joined"})
    else
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
         {sid, _} <- Integer.parse(sender_id),
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
end