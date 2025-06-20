defmodule Rambo.Redis.ExpiryHandler do
  use GenServer
  require Logger

  alias Rambo.Redis.RedisMessageStore
  alias Rambo.Repo
  import Ecto.Query

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Redis PubSub 연결 생성
    {:ok, conn} = Redix.PubSub.start_link(
      Application.get_env(:rambo, :redis_url),
      name: :redix_pubsub
    )

    # 만료 이벤트 구독
    {:ok, ref} = Redix.PubSub.psubscribe(conn, "__keyevent@0__:expired", self())

    {:ok, %{conn: conn, ref: ref}}
  end

  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :pmessage, %{payload: key}}, state) do
    Logger.info("구독중~~ key space ex 이벤트")
    handle_expired_key(key)
    {:noreply, state}
  end

  # 구독 확인 메시지 처리
  def handle_info({:redix_pubsub, _pid, _ref, :psubscribed, %{pattern: pattern}}, state) do
    Logger.info("Successfully subscribed to pattern: #{pattern}")
    {:noreply, state}
  end

  # 연결 끊김 처리
  def handle_info({:redix_pubsub, _pid, _ref, :disconnected, %{error: error}}, state) do
    Logger.error("Redis PubSub disconnected: #{inspect(error)}")
    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp handle_expired_key(key) do

    Logger.info("redis key 만료 메시지 받음 key : #{inspect(key)}")
    if String.match?(key, ~r/^room:\d+#user:\d+$/) do
      Logger.info("key 형식 일치: #{key}")
      try do
        # key 형식: room:123#user:456
        [room_part, user_part] = String.split(key, "#")
        room_id = room_part |> String.replace("room:", "") |> String.to_integer()
        user_id = user_part |> String.replace("user:", "") |> String.to_integer()

        # Redis에서 해당 유저의 마지막 읽은 메시지 키 가져오기
        Logger.info("backupkey 조회 room_id=#{room_id}, user_id=#{user_id}")
        case RedisMessageStore.get_user_last_read_backup(room_id, user_id) do
          nil ->
            Logger.info("backupkey 없음, 읽은것도 없다고 간주 room_id=#{room_id}, user_id=#{user_id}")
            nil # 없으면 읽은것도 없다고 간주
          last_read_key ->
            Logger.info("backupkey 있음, 읽은것도 있다고 간주 room_id=#{room_id}, user_id=#{user_id} last_read_key=#{last_read_key}")
            # talk_room_users 테이블에서 단일 레코드 조회 후 업데이트
            case from(tu in Rambo.TalkRoomUser,
              where: tu.talk_room_id == ^room_id and tu.user_id == ^user_id
            ) |> Repo.one() do
              nil ->
                Logger.warning("talk_room_user not found for room_id=#{room_id}, user_id=#{user_id}")
              talk_room_user ->
                talk_room_user
                |> Ecto.Changeset.change(%{
                  last_read_message_key: last_read_key,
                  updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
                })
                |> Repo.update()
            end

            RedisMessageStore.delete_user_last_read_backup(room_id, user_id)
            Logger.info("last_read_message_key 업데이트, backupkey 삭제 room_id=#{room_id}, user_id=#{user_id}")

          {:error, :not_found} ->
            Logger.warning("not found error, room_id=#{room_id}, user_id=#{user_id}")

          {:error, reason} ->
            Logger.error("에러 발생!! 이유는 #{inspect(reason)}")
        end
      rescue
        e ->
          Logger.error("Failed to handle expiry for key #{key}: #{inspect(e)}")
      end
    end
  end

  @doc """
  현재 Redis PubSub 구독 상태를 확인합니다.
  """
  def subscription_status do
    GenServer.call(__MODULE__, :subscription_status)
  end

  @doc """
  Redis PubSub 연결 상태를 확인합니다.
  """
  def connection_status do
    GenServer.call(__MODULE__, :connection_status)
  end

  @doc """
  수동으로 만료 이벤트 구독을 재시작합니다.
  """
  def resubscribe do
    GenServer.call(__MODULE__, :resubscribe)
  end

  @impl true
  def handle_call(:subscription_status, _from, state) do
    # Redix.PubSub에는 구독 상태를 직접 조회하는 API가 없음
    # 대신 현재 상태에서 ref가 있는지로 판단
    if state.ref do
      Logger.info("구독 중: __keyevent@0__:expired (ref: #{inspect(state.ref)})")
      {:reply, {:ok, [%{pattern: "__keyevent@0__:expired", ref: state.ref}]}, state}
    else
      Logger.warning("구독되지 않음")
      {:reply, {:error, :not_subscribed}, state}
    end
  end

  @impl true
  def handle_call(:connection_status, _from, state) do
    # Redix.PubSub 연결 상태 확인
    if Process.alive?(state.conn) do
      Logger.info("Redis PubSub 연결 상태: 연결됨 (conn: #{inspect(state.conn)})")
      {:reply, {:ok, %{connected: true, conn: state.conn}}, state}
    else
      Logger.error("Redis PubSub 연결 상태: 연결 끊김")
      {:reply, {:error, :disconnected}, state}
    end
  end

  @impl true
  def handle_call(:resubscribe, _from, state) do
    Logger.info("만료 이벤트 구독 재시작")

    # 기존 구독 해제
    Redix.PubSub.punsubscribe(state.conn, "__keyevent@0__:expired", self())

    # 새로 구독
    case Redix.PubSub.psubscribe(state.conn, "__keyevent@0__:expired", self()) do
      {:ok, ref} ->
        Logger.info("✅ 만료 이벤트 구독 재시작 성공")
        {:reply, {:ok, ref}, %{state | ref: ref}}
      error ->
        Logger.error("❌ 만료 이벤트 구독 재시작 실패: #{inspect(error)}")
        {:reply, {:error, error}, state}
    end
  end
end
