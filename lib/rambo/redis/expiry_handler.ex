defmodule Rambo.Redis.ExpiryHandler do
  use GenServer
  require Logger

  alias Rambo.Redis.RedisMessageStore

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Redis Keyspace 이벤트를 구독하기 위한 새로운 Redix 연결 생성
    {:ok, conn} = Redix.start_link(Application.get_env(:rambo, :redis_url))

    # Keyspace 이벤트 구독 설정
    Redix.command(conn, ["CONFIG", "SET", "notify-keyspace-events", "Ex"])

    # 만료 이벤트 채널 구독
    Redix.command(conn, ["SUBSCRIBE", "__keyevent@0__:expired"])

    {:ok, %{conn: conn}}
  end

  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :message, %{channel: "__keyevent@0__:expired", payload: key}}, state) do
    handle_expired_key(key)
    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp handle_expired_key(key) do
    if String.starts_with?(key, "expire:latest_messages:") do
      room_id = String.replace_prefix(key, "expire:latest_messages:", "")

      case RedisMessageStore.get_last_message(room_id) do
        {:ok, message} ->
          Logger.info("메시지 만료 처리: room_id=#{room_id}, message=#{message}")
          # @TODO RDB에 저장하는 로직 추가

        {:error, :not_found} ->
          Logger.warn("만료된 메시지를 찾을 수 없음: room_id=#{room_id}")

        {:error, reason} ->
          Logger.error("메시지 만료 처리 중 에러 발생: room_id=#{room_id}, error=#{inspect(reason)}")
      end
    end
  end
end
