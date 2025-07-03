defmodule Rambo.TalkRoomService do
  @moduledoc """
  TalkRoom 생성, 참여, 읽음 처리 등 채팅방 관련 서비스 로직
  이벤트 관련 로직은 빠져있음,
  이벤트 발행을 위해 필요한 정보나 rdb, ddb, redis 접근 포함
  """
  require Logger

  alias Rambo.Repo
  alias Rambo.TalkRoom
  alias Rambo.TalkRoomUser
  alias Rambo.Ddb.DynamoDbService
  alias Rambo.Redis.RedisMessageStore
  alias Rambo.RedisClient
  import Ecto.Query

  ## 1. 채팅방 생성 / 호출부에서 join 이벤트 발행 필요
  def create_room(attrs) do
    case %TalkRoom{}
         |> TalkRoom.changeset(attrs)
         |> Repo.insert() do
      {:ok, room} -> TalkRoom.set_ddb_id(room)
      error -> error
    end
  end

  ## 2. 채팅방 참여 TalkRoomUser 생성 / 호출부에서 join 이벤트 발행 필요
  def join(talk_room_id, user_id) do
    %TalkRoomUser{}
    |> TalkRoomUser.changeset(%{
      talk_room_id: talk_room_id,
      user_id: user_id,
      joined_at: NaiveDateTime.utc_now()
    })
    |> Repo.insert(on_conflict: :nothing) # 중복 참여 방지
    # 성공시 참여 이벤트 발행

  end

  ## 3. 특정 채팅방 참여리스트
  def list_users(talk_room_id) do
    from(u in TalkRoomUser, where: u.talk_room_id == ^talk_room_id)
    |> Repo.all()
  end

  ## 4. redis에 마지막으로 읽은 메시지키 set
  def mark_as_read(talk_room_id, user_id, last_read_key) do
    RedisMessageStore.update_user_last_read(talk_room_id, user_id, last_read_key)
  end

  def list_rooms do
    Repo.all(TalkRoom)
  end

  def get_last_read_key_from_rdb(room_id, user_id) do
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

  # 유저가 참여한 채팅방 목록
  def participate_list_with_unread_count(user_id) do
    query =
      from r in TalkRoom,
           join: m in TalkRoomUser,
           on: m.talk_room_id == r.id,
           where: m.user_id == ^user_id,
           select: {r, m.last_read_message_key},
           preload: :talk_room_users

    Repo.all(query)
    |> Enum.map(fn {room, last_read_key_from_rdb} ->
      {last_read_key, unread_count} = get_last_read_key_and_unread_message_count(room, user_id, last_read_key_from_rdb)
        Logger.info("unread_count: #{unread_count}")
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


  # 안읽은 메시지갯수 가져오는 함수
  # redis에 있으면 redis에서 가져오고 없으면 rdb 메시지키 보고 sequence는 ddb조회해서 가져오기
  def get_last_read_key_and_unread_message_count(room, user_id, last_read_key_from_rdb) do
    {:ok, room_max_seq} = RedisMessageStore.get_room_max_sequence(room.id)
    redis_room_user_key = "room:#{room.id}#user:#{user_id}"

    last_read_key = case RedisClient.get(redis_room_user_key) do
      {:ok, nil} ->
        last_read_key_from_rdb
      {:ok, value} ->
        value
    end

    case last_read_key do
      nil -> {last_read_key, room_max_seq} # 없으면 모두 안읽었다고 생각하고 최대 시퀀스 가져오기
      message_id ->
        {:ok, last_read_msg_seq} = DynamoDbService.get_message_sequence(room.id, message_id)
        {last_read_key, room_max_seq - last_read_msg_seq}
    end
  end

  def get_room_by_id(room_id) do
    case Repo.get(TalkRoom, room_id) do
      nil -> {:error, "Room not found"}
      room -> {:ok, room}
    end
  end

  def get_latest_message_id(room_id) do
    case DynamoDbService.get_messages(room_id, limit: 1, sort_order: :desc) do
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
