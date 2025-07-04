defmodule Rambo.TalkRoomService do
  @moduledoc """
  TalkRoom 생성, 참여, 읽음 처리 등 채팅방 관련 서비스 로직
  이벤트 발행을 위해 필요한 정보나 rdb, ddb, redis 접근 포함
  """
  require Logger

  alias Rambo.{Repo, TalkRoom, TalkRoomUser, Users.User}
  alias Rambo.Ddb.DynamoDbService
  alias Rambo.Redis.RedisMessageStore
  alias Rambo.RedisClient
  import Ecto.Query
  alias Phoenix.PubSub

  @pubsub Rambo.PubSub

  ## 1. 채팅방 생성 및 생성자 참여를 트랜잭션으로 처리
  def create_room(attrs, creator_id) do
    with {:ok, _user} <- User.get_active_user(creator_id) do
      Repo.transaction(fn ->
        with {:ok, room} <- TalkRoom.create(attrs),
             {:ok, room_with_ddb_pk} <- TalkRoom.set_ddb_id(room) do
              room_with_ddb_pk
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  ## 2. 채팅방 참여 create_room에서 받은 콜백으로 join push
  def join_talk(talk_room_id, user_id) do
    with {:ok, user} <- User.get_active_user(user_id),
         {:ok, room} <- TalkRoom.get(talk_room_id) do
      TalkRoomUser.create(%{
        talk_room_id: room.id,
        user_id: user.id,
        joined_at: NaiveDateTime.utc_now()
      })
      # 소켓 join 이벤트 발행

      {:ok, room}
    end
  end

  ## 3. 특정 채팅방 참여리스트
  def list_users(talk_room_id) do
    TalkRoomUser.list_by_room(talk_room_id)
  end

  ## 4. redis에 마지막으로 읽은 메시지키 set
  def mark_as_read(talk_room_id, user_id, last_read_key) do
    RedisMessageStore.update_user_last_read(talk_room_id, user_id, last_read_key)
  end

  def list_rooms do
    TalkRoom.list()
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

  def get_latest_message_id(room_id) do
    case DynamoDbService.get_messages(room_id, limit: 1, sort_order: :desc) do
      {:ok, [latest | _]} -> {:ok, latest.message_id}
      _ -> {:ok, nil}
    end
  end

  def touch_activity(room_id) do
    TalkRoom.touch_activity(room_id)
  end

  #########################################################
  # PRIVATE FUNCTIONS
  #########################################################

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


  def get_last_read_key_from_rdb(room_id, user_id) do
    TalkRoomUser.get_last_read_key(room_id, user_id)
  end

  defp broadcast_room_join(room, creator_id) do
    payload = %{
      type: "system",
      event: "join",
      room_id: room.id,
      name: room.name,
      creator_id: creator_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    PubSub.broadcast(@pubsub, "talk:#{room.id}", {:room_created, payload})
  end
end
