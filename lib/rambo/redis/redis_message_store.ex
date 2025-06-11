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

    IO.puts("#{key} 인크리먼트 되었나? 여길 타긴타나 ")
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
  defp fetch_max_sequence_from_dynamo(room_id) do
    query_params = %{
      "TableName" => "messages",
      "KeyConditionExpression" => "chat_room_id = :room_id",
      "ExpressionAttributeValues" => %{
        ":room_id" => %{"S" => to_string(room_id)}
      },
      "ScanIndexForward" => false,
      "Limit" => 1  # 가장 최근 메시지 1개만 조회
    }

    case ExAws.Dynamo.query(query_params) |> ExAws.request() do
      {:ok, %{"Items" => [latest_msg | _]}} ->
        sequence = String.to_integer(latest_msg["sequence"]["N"])
        # 조회한 값을 Redis에 캐시 (증가시키지 않고 그대로 저장)
        RedisClient.set("#{@redis_room_max_sequence_key}:#{room_id}", sequence)
        {:ok, sequence}

      {:ok, %{"Items" => []}} ->
        # 메시지가 없는 경우 0 반환
        {:ok, 0}

      {:error, reason} = error ->
        Logger.error("DynamoDB에서 최대 순번 조회 실패: #{inspect(reason)}")
        error
    end
  end
end
