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
    if String.match?(key, ~r/^room:\d+#user:\d+$/) do
      try do
        # key 형식: room:123#user:456
        [room_part, user_part] = String.split(key, "#")
        room_id = room_part |> String.replace("room:", "") |> String.to_integer()
        user_id = user_part |> String.replace("user:", "") |> String.to_integer()

        # Redis에서 해당 유저의 마지막 읽은 메시지 키 가져오기
        case RedisMessageStore.get_user_last_read(room_id, user_id) do
          {:ok, last_read_key} ->
            # talk_room_users 테이블 업데이트
            from(tu in "talk_room_users",
              where: tu.room_id == ^room_id and tu.user_id == ^user_id
            )
            |> Repo.update_all(
              set: [
                last_read_message_key: last_read_key,
                updated_at: DateTime.utc_now()
              ]
            )

            Logger.info("last_read_message_key 업데이트 room_id=#{room_id}, user_id=#{user_id}")

          {:error, :not_found} ->
            Logger.warn("not found error, room_id=#{room_id}, user_id=#{user_id}")

          {:error, reason} ->
            Logger.error("에러 발생!! 이유는 #{inspect(reason)}")
        end
      rescue
        e ->
          Logger.error("Failed to handle expiry for key #{key}: #{inspect(e)}")
      end
    end
  end
end
