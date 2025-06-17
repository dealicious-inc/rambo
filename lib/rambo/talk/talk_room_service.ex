defmodule Rambo.TalkRoomService do
  @moduledoc """
  TalkRoom 생성, 참여, 읽음 처리 등 채팅방 관련 서비스 로직
  """

  alias Rambo.Repo
  alias Rambo.TalkRoom
  alias Rambo.TalkRoomUser
  import Ecto.Query

  ## 1. 채팅방 생성
  def create_room(%{room_type: room_type, name: name, ddb_id: ddb_id}) do
    %TalkRoom{}
    |> TalkRoom.changeset(%{room_type: room_type, name: name, ddb_id: ddb_id})
    |> Repo.insert()
  end

  ## 2. 채팅방에 유저 참여
  def join_user(talk_room_id, user_id) do
    %TalkRoomUser{}
    |> TalkRoomUser.changeset(%{
      talk_room_id: talk_room_id,
      user_id: user_id,
      joined_at: NaiveDateTime.utc_now()
    })
    |> Repo.insert(on_conflict: :nothing) # 중복 참여 방지
  end

  ## 3. 채팅방 유저 불러오기
  def list_users(talk_room_id) do
    from(u in TalkRoomUser, where: u.talk_room_id == ^talk_room_id)
    |> Repo.all()
  end

  ## 4. 마지막으로 읽은 메시지 기록
  def mark_as_read(talk_room_id, user_id, last_read_key) do
    from(u in TalkRoomUser,
      where: u.talk_room_id == ^talk_room_id and u.user_id == ^user_id
    )
    |> Repo.update_all(set: [last_read_message_key: last_read_key])
  end

  ## 5. 1:1 채팅방 찾거나 생성
  def find_or_create_private_room(user1_id, user2_id) do
    {uid1, uid2} = Enum.min_max([user1_id, user2_id])
    name = "#{uid1}_#{uid2}"

    case Repo.get_by(TalkRoom, room_type: "private", name: name) do
      nil ->
        # 없으면 새로 만들고 둘 다 참여
        Repo.transaction(fn ->
          {:ok, room} =
            %TalkRoom{}
            |> TalkRoom.changeset(%{room_type: "private", name: name})
            |> Repo.insert()

          join_user(room.id, uid1)
          join_user(room.id, uid2)

          room
        end)

      room ->
        {:ok, room}
    end
  end

  def list_rooms do
    Repo.all(TalkRoom)
  end

  def get_last_read_key(room_id, user_id) do
    from(u in TalkRoomUser,
      where: u.talk_room_id == ^room_id and u.user_id == ^user_id,
      select: u.last_read_message_key
    )
    |> Repo.one()
    |> case do
         nil -> :not_found
         key -> {:ok, key}
       end
  end

  def participate_list(user_id) do
    # 유저가 참여한 채팅방 목록
    query =
      from r in TalkRoom,
           join: m in TalkRoomUser,
           on: m.talk_room_id == r.id,
           where: m.user_id == ^user_id,
           select: {r, m.last_read_message_key},
           preload: :talk_room_users

    Repo.all(query)
    |> Enum.map(fn {room, last_read_key} ->

      unread_count =
        case Rambo.Talk.MessageStore.count_messages_after(room, last_read_key, user_id) do
          {:ok, count} -> count
          _ -> 0
        end

      %{
        id: room.id,
        name: room.name,
        room_type: room.room_type,
        unread_count: unread_count,
        last_read_message_key: last_read_key,
        last_activity_at: room.last_activity_at
      }
    end)
  end

  def get_room_by_id(room_id) do
    case Repo.get(TalkRoom, room_id) do
      nil -> {:error, "Room not found"}
      room -> {:ok, room}
    end
  end

  def get_latest_message_id(room_id) do
    case Rambo.Talk.MessageStore.get_messages(room_id, limit: 1) do
      {:ok, [latest | _]} -> {:ok, latest.message_id}
      _ -> {:ok, nil}
    end
  end

  def touch_activity(room_id) do
    {_, _} =
      from(r in TalkRoom, where: r.id == ^room_id)
      |> Repo.update_all(set: [last_activity_at: DateTime.utc_now()])

    :ok
  end
end
