defmodule Rambo.Redis.RedisMessageStore do
  @moduledoc """
  Redis를 사용해서 메시지 관련 데이터를 관리하는 모듈
  """

  require Logger
  alias Rambo.RedisClient
  alias Rambo.Ddb.DynamoDbService

  # 유저의 마지막 읽은 메시지 정보 만료 시간 (1시간)
  @ttl_seconds 10
  @back_key_ttl_seconds @ttl_seconds+30
  @redis_room_max_sequence_key "room_max_sequence"

  def redis_room_max_sequence_key, do: @redis_room_max_sequence_key

@doc """
방의 최대 메시지 sequence를 Redis에 저장

## Returns

  * :ok - 성공
  * {:error, :redis_incr_failed} - Redis incr 작업 실패
  * {:error, :redis_set_failed} - Redis set 작업 실패
  * {:error, :dynamo_fetch_failed} - DynamoDB 조회 실패
  * {:error, reason} - 기타 에러
"""
def update_room_max_sequence(room_id) do
  key = "#{@redis_room_max_sequence_key}:#{room_id}"

  if RedisClient.exists?(key) do
    case RedisClient.incr(key) do
      {:ok, _} -> :ok
      error ->
        Logger.error("Redis incr 실패 - room_id: #{room_id}, error: #{inspect(error)}")
        {:error, :redis_incr_failed}
    end
  else
    with {:ok, max_sequence} <- DynamoDbService.fetch_max_sequence_from_dynamo(room_id),
         {:ok, _} <- RedisClient.set(key, to_string(max_sequence)) do
      update_room_max_sequence(room_id)
    else
      error ->
        Logger.error("방 최대 sequence 초기화 실패 - room_id: #{room_id}, error: #{inspect(error)}")
        case error do
          {:error, :dynamo_error} -> {:error, :dynamo_fetch_failed}
          _ -> {:error, :redis_set_failed}
        end
    end
  end
end


  @doc """
  특정 유저가 특정 방에서 마지막으로 읽은 메시지 정보를 Redis에 저장
  """
  def update_user_last_read(room_id, user_id, message_key) do
    key = "room:#{room_id}#user:#{user_id}"
    backup_key = "backup#room:#{room_id}#user:#{user_id}"
    Logger.debug("유저 마지막 읽은 메시지 업데이트: #{key} = #{message_key}")

    case RedisClient.set(key, message_key) do
      :ok ->
        RedisClient.set(backup_key, message_key)
        case RedisClient.expire(key, @ttl_seconds) do
          :ok ->
            RedisClient.expire(backup_key, @back_key_ttl_seconds)
            Logger.info("유저 마지막 읽은 메시지 ttl_seconds 업데이트 성공: #{key} = #{message_key}")
            :ok
          error ->
            Logger.error("유저 마지막 읽은 메시지 expire 설정 실패: key=#{key}, ttl=#{@ttl_seconds}, error=#{inspect(error, pretty: true)}")
            error
        end
      error ->
        Logger.error("유저 마지막 읽은 메시지 set 실패: key=#{key}, message_key=#{message_key}, error=#{inspect(error, pretty: true)}")
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
        Logger.info("Redis에 있으면 Redis에서 조회")
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

  def get_user_last_read_backup(room_id, user_id) do
    Logger.info("함수안임 backupkey 조회  room_id=#{room_id}, user_id=#{user_id}")
    key = get_backup_key(room_id, user_id)
    case RedisClient.get(key) do
      {:ok, nil} ->  nil
      {:ok, value} -> value
      result -> result
    end
  end

  def delete_user_last_read_backup(room_id, user_id) do
    key = get_backup_key(room_id, user_id)
    RedisClient.del(key)
  end

  defp get_backup_key(room_id, user_id) do
    "backup#room:#{room_id}#user:#{user_id}"
  end
end
