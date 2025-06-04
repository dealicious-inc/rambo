defmodule Rambo.Redis.RedisMessageStore do
  @moduledoc """
  Redis를 사용해서 메시지 키를 관리하는 공통 서비스 모듈
  """

  alias Rambo.RedisClient

  @redis_hash_key "latest_messages"
  @redis_expire_prefix "expire:latest_messages"
  @ttl_seconds 3600 # 1시간 동안 메시지 안오고가면 해당 룸에 대한 최근 메시지 count 정보 삭제

  @doc """
  room_id에 대해 마지막 메시지를 Redis Hash와 만료 키로 갱신
  """
  @spec put_last_message(String.t(), String.t()) :: :ok | {:error, term()}
  def put_last_message(room_id, message_ddb_pk) do
    with {:ok, _} <- RedisClient.set("#{@redis_expire_prefix}:#{room_id}", "1"), # 메시지 만료여부만 체크하기위한 키밸류쌍
         :ok <- RedisClient.expire("#{@redis_expire_prefix}:#{room_id}", @ttl_seconds),
         {:ok, _} <- RedisClient.set("#{@redis_hash_key}:#{room_id}", message_ddb_pk) do
      :ok
    else
      error -> error
    end
  end

  @doc """
  만료 이벤트 핸들러에서 마지막 메시지 값을 가져올 때 사용
  이거 가져다가 rdb에 저장할 예정
  """
  @spec get_last_message(String.t()) :: {:ok, String.t()} | {:error, term()}
  def get_last_message(room_id) do
    RedisClient.get("#{@redis_hash_key}:#{room_id}")
  end
end
