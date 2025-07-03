defmodule RamboWeb.Api.TalkRoomController do
  use RamboWeb, :controller

  alias Rambo.TalkRoomService

  # 채팅방 목록 조회
  def index(conn, _params) do
    rooms = TalkRoomService.list_rooms()

    json(conn, rooms)
  end

  # 채팅방 생성
  def create(conn, %{"name" => name, "room_type" => room_type, "user_id" => user_id}) do

    # 채팅방 생성
    case TalkRoomService.create_room(%{room_type: room_type, name: name}) do
      {:ok, room} ->
        json(conn, %{room_id: room.id, name: room.name, ddb_id: room.ddb_id})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: changeset_errors(changeset)})
    end
  end

  # 채팅방 참여
  def join(conn, %{"id" => room_id, "user_id" => user_id}) do
    rid = if is_binary(room_id), do: String.to_integer(room_id), else: room_id
    user_id = if is_binary(user_id), do: String.to_integer(user_id), else: user_id

    case TalkRoomService.join(rid, user_id) do
      {:ok, _} ->
        # ✅ 초대된 유저 개인 채널로 NATS 메시지 발행 → 로비에서 수신
        payload = %{type: "invitation", room_id: rid, to_user_id: user_id}
        Rambo.Nats.JetStream.publish("talk.user.#{user_id}", Jason.encode!(payload))
        TalkRoomService.touch_activity(rid)

        json(conn, %{message: "joined"})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Join failed"})
    end
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  def participate_list(conn, %{"user_id" => user_id_str}) do
    {user_id, _} = Integer.parse(user_id_str)

    rooms = Rambo.TalkRoomService.participate_list_with_unread_count(user_id)

    json(conn, rooms)
  end

  def send_message(conn, %{"id" => room_id, "sender_id" => sender_id, "message" => message}) do
    with {rid, _} <- Integer.parse(room_id),
         sid when is_integer(sid) <- sender_id,
         {:ok, room} <- Rambo.TalkRoomService.get_room_by_id(rid),

         {:ok, item} <- Rambo.Talk.MessageStore.store_message(%{
           room_id: "#{rid}",
           sender_id: sid,
           message: message,
           name: room.name,
           ddb_id: room.ddb_id
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

  def mark_read(conn, %{
    "id" => room_id,
    "userid" => user_id,
    "last_read_key" => last_read_key
  }) do
    with {rid, _} <- Integer.parse(room_id),
         user_id <- parse_int(user_id),
         {count, _} <- TalkRoomService.mark_as_read(rid, user_id, last_read_key) do
      json(conn, %{updated: count})
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "Failed to mark as read"})
    end
  end

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
end
