defmodule Rambo.RedisClient do
  @moduledoc """
  Redis 클라이언트 모듈
  """

  require Logger

  def set(key, value) when is_binary(key) do
    Logger.debug("Redis SET 시도: key=#{key}, value=#{inspect(value)}")
    case Redix.command(Rambo.Redis, ["SET", key, to_string(value)]) do
      {:ok, "OK"} ->
        Logger.info("Redis SET 성공")
        :ok
      error ->
        Logger.error("Redis SET 실패: #{inspect(error)}")
        error
    end
  end

  @typedoc """
  @spec get(String.t()) :: {:ok, String.t()} | {:error, any()}
  """
  def get(key) when is_binary(key) do
    case Redix.command(Rambo.Redis, ["GET", key]) do
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> {:ok, value}
      error -> error
    end
  end

  def exists?(key) when is_binary(key) do
    case Redix.command(Rambo.Redis, ["EXISTS", key]) do
      {:ok, 1} -> true
      {:ok, 0} -> false
      _ -> false
    end
  end

  def delete(key) when is_binary(key) do
    Redix.command(Rambo.Redis, ["DEL", key])
  end

  def expire(key, seconds) when is_binary(key) and is_integer(seconds) and seconds > 0 do
    Logger.info("Redis EXPIRE 시도: key=#{key}, seconds=#{seconds}")
    case Redix.command(Rambo.Redis, ["EXPIRE", key, to_string(seconds)]) do
      {:ok, 1} -> :ok
      {:ok, 0} -> {:error, :key_not_found}
      error -> Logger.error("Redis EXPIRE 실패: key=#{key}, seconds=#{seconds}, error=#{inspect(error, pretty: true)}")
      error
    end
  end

  def incr(key) when is_binary(key) do
    Redix.command(Rambo.Redis, ["INCR", key])
  end

  # Redis hash table 관련 함수들
  # 일단 지금은 불필요해서 주석 처리
  # def hset(key, field, value) when is_binary(key) and is_binary(field) do
  #   Redix.command(Rambo.Redis, ["HSET", key, field, value])
  # end

  # def hget(key, field) when is_binary(key) and is_binary(field) do
  #   case Redix.command(Rambo.Redis, ["HGET", key, field]) do
  #     {:ok, nil} -> {:error, :not_found}
  #     {:ok, value} -> {:ok, value}
  #     error -> error
  #   end
  # end

  # def hgetall(key) when is_binary(key) do
  #   case Redix.command(Rambo.Redis, ["HGETALL", key]) do
  #     {:ok, []} -> {:error, :not_found}
  #     {:ok, values} -> {:ok, Enum.chunk_every(values, 2) |> Enum.into(%{}, fn [k, v] -> {k, v} end)}
  #     error -> error
  #   end
  # end

  def del(key) when is_binary(key) do
    Logger.info("Redis DEL 시도: key=#{key}")
    case Redix.command(Rambo.Redis, ["DEL", key]) do
      {:ok, 1} -> :ok
      {:ok, 0} -> {:error, :key_not_found}
      error ->
        Logger.error("Redis DEL 실패: key=#{key}, error=#{inspect(error, pretty: true)}")
        error
    end
  end
end
