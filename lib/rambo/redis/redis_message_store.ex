defmodule Rambo.Redis.RedisMessageStore do
  @moduledoc """
  Redis를 사용해서 메시지 관련 데이터를 관리하는 모듈
  """

  require Logger
  alias Rambo.RedisClient

  # 방의 최대 메시지 sequence를 저장하는 Redis 키 접두사
  @redis_room_max_sequence_key "room_max_sequence"
  # 유저의 마지막 읽은 메시지 정보 만료 시간 (1시간)
  @ttl_seconds 3600

  @doc """
  방의 최대 메시지 sequence를 Redis에 저장
  """
  def update_room_max_sequence(room_id) do
    key = "#{@redis_room_max_sequence_key}:#{room_id}"
    Logger.debug("방 최대 메시지 순번 업데이트: #{key}")
    if RedisClient.exists?(key) do
      case RedisClient.incr(key) do
        {:ok, _} -> :ok
        error -> error
      end
    else
      case fetch_max_sequence_from_dynamo(room_id) do
        {:ok, max_sequence} ->
          RedisClient.set(key, to_string(max_sequence + 1))
        error -> error
      end
    end
  end

  @doc """
  특정 유저가 특정 방에서 마지막으로 읽은 메시지 정보를 Redis에 저장합니다.
  """
  def update_user_last_read(room_id, user_id, message_key) do
    key = "room:#{room_id}#user:#{user_id}"
    Logger.debug("유저 마지막 읽은 메시지 업데이트: #{key} = #{message_key}")

    with {:ok, _} <- RedisClient.set(key, message_key),
         :ok <- RedisClient.expire(key, @ttl_seconds) do
      :ok
    else
      error ->
        Logger.error("유저 마지막 읽은 메시지 업데이트 실패: #{inspect(error)}")
        error
    end
  end

  @doc """
  방의 최대 메시지 sequence를 조회합니다.
  Redis에 없는 경우 DynamoDB에서 최근 메시지의 sequence를 조회합니다.
  """
  def get_room_max_sequence(room_id) do
    key = "#{@redis_room_max_sequence_key}:#{room_id}"

    case RedisClient.get(key) do
      {:ok, nil} ->
        # Redis에 없으면 DynamoDB에서 조회
        Logger.info("Redis에 없으면 DynamoDB에서 조회")
        fetch_max_sequence_from_dynamo(room_id)

      {:ok, value} ->
        {:ok, String.to_integer(value)}

      error ->
        Logger.error("방 최대 메시지 순번 조회 실패: #{inspect(error)}")
        error
    end
  end

  @doc """
  특정 유저가 특정 방에서 마지막으로 읽은 메시지 정보를 조회합니다.

  ## 매개변수
    - room_id: 방 ID
    - user_id: 사용자 ID
  """
  def get_user_last_read(room_id, user_id) do
    key = "room:#{room_id}#user:#{user_id}"
    case RedisClient.get(key) do
      {:ok, nil} -> {:error, :not_found}
      result -> result
    end
  end

  # 내부 함수

  @doc false
  def fetch_max_sequence_from_dynamo(room_id) do
    pk = "room:#{room_id}"

    Logger.info("pk: #{pk} 다이나모에서 찾기 시작 #{room_id}")
    query_params = [
      key_condition_expression: "pk = :pk",
      expression_attribute_values: [pk: pk],
      scan_index_forward: false,
      limit: 1
    ]

    case ExAws.Dynamo.query("messages", query_params) |> ExAws.request() do
      {:ok, response} ->
        # 전체 응답 구조 확인
        Logger.info("📋 DynamoDB 쿼리 전체 응답: #{inspect(response, pretty: true, limit: :infinity)}")

        case response do
          %{"Items" => [latest_msg | _]} ->
            Logger.info("📝 최신 메시지: #{inspect(latest_msg, pretty: true, limit: :infinity)}")

            sequence = String.to_integer(latest_msg["sequence"]["N"])
            Logger.info("🔢 추출된 sequence: #{sequence}")

            RedisClient.set("#{@redis_room_max_sequence_key}:#{room_id}", sequence)
            {:ok, sequence}

          %{"Items" => []} ->
            Logger.info("📭 메시지가 없습니다")
            {:ok, 0}
        end

      {:error, reason} = error ->
        Logger.error("❌ DynamoDB 쿼리 실패: #{inspect(reason, pretty: true, limit: :infinity)}")
        error
    end
  end
end
