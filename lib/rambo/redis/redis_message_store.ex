defmodule Rambo.Redis.RedisMessageStore do
  @moduledoc """
  Redis를 사용해서 메시지 관련 데이터를 관리하는 모듈
  """

  require Logger
  alias Rambo.RedisClient
  alias Rambo.Ddb.DynamoDbService

  # 유저의 마지막 읽은 메시지 정보 만료 시간 (1시간)
  @ttl_seconds 3600
  @redis_room_max_sequence_key "room_max_sequence"

  def redis_room_max_sequence_key, do: @redis_room_max_sequence_key

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
      case DynamoDbService.fetch_max_sequence_from_dynamo(room_id) do
        {:ok, max_sequence} ->
          RedisClient.set(key, to_string(max_sequence))
        error -> error
      end
    end
  end

  @doc """
  특정 유저가 특정 방에서 마지막으로 읽은 메시지 정보를 Redis에 저장
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
  방의 최대 메시지 sequence를 조회
  Redis에 없는 경우 DynamoDB에서 최근 메시지의 sequence를 조회
  """
  def get_room_max_sequence(room_id) do
    key = "#{redis_room_max_sequence_key()}:#{room_id}"

    case RedisClient.get(key) do
      {:ok, nil} ->
        # Redis에 없으면 DynamoDB에서 조회
        Logger.info("Redis에 없으면 DynamoDB에서 조회")
        DynamoDbService.fetch_max_sequence_from_dynamo(room_id)

      {:ok, value} ->
        {:ok, String.to_integer(value)}

      error ->
        Logger.error("방 최대 메시지 순번 조회 실패: #{inspect(error)}")
        error
    end
  end

  @doc """
  특정 유저가 특정 방에서 마지막으로 읽은 메시지 정보를 조회
  redis에 없으면 rdb에서 조회
  ## 매개변수
    - room_id: 방 ID
    - user_id: 사용자 ID
  """
  def get_user_last_read(room_id, user_id) do
    key = "room:#{room_id}#user:#{user_id}"
    case RedisClient.get(key) do
      {:ok, nil} ->  nil
      {:ok, value} -> value
      result -> result
    end
  end
end
