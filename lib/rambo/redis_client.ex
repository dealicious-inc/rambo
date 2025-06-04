defmodule Rambo.RedisClient do
  @moduledoc """
  Redis 클라이언트 모듈
  """

  def set(key, value) when is_binary(key) do
    Redix.command(Rambo.Redis, ["SET", key, value])
  end

  def get(key) when is_binary(key) do
    case Redix.command(Rambo.Redis, ["GET", key]) do
      {:ok, nil} -> {:error, :not_found}
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
    Redix.command(Rambo.Redis, ["EXPIRE", key, to_string(seconds)])
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
end
