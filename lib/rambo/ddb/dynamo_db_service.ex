defmodule Rambo.Ddb.DynamoDbService do
  @table "messages"
  require Logger

  alias Rambo.RedisClient
  alias Rambo.Redis.RedisMessageStore

  # ddb에서 message_id로 메시지 sequence 조회
  @typedoc """
  @spec get_message_sequence(String.t(), String.t()) :: {:ok, integer()} | {:error, any()}
  """
  def get_message_sequence(room_id, message_id) do
    pk = "room:#{room_id}"

    ExAws.Dynamo.query(@table,
      key_condition_expression: "pk = :pk AND message_id = :message_id",
      expression_attribute_values: [pk: pk, message_id: message_id],
      index_name: "message_id_gsi",
      limit: 1
    ) |> ExAws.request()
    |> case do
      {:ok, %{"Items" => [item]}} ->
        sequence = case item["sequence"] do
          %{"N" => seq} -> String.to_integer(seq)
          seq when is_integer(seq) -> seq
          seq when is_binary(seq) -> String.to_integer(seq)
          _ -> 0
        end
        {:ok, sequence}
      {:ok, %{"Items" => []}} -> {:ok, 0}
      error -> error
    end
  end

  # ddb에서 room_id로 최대 sequence 조회
  @typedoc """
  @spec fetch_max_sequence_from_dynamo(String.t()) :: {:ok, integer()} | {:error, any()}
  """
  def fetch_max_sequence_from_dynamo(room_id) do
    pk = "room:#{room_id}"

    Logger.info("pk: #{pk} 다이나모에서 최대 seq 찾기 시작 #{room_id}")
    query_params = [
      key_condition_expression: "pk = :pk",
      expression_attribute_values: [pk: pk],
      scan_index_forward: false,
      limit: 1
    ]

    case ExAws.Dynamo.query("messages", query_params) |> ExAws.request() do
      {:ok, response} ->
        case response do
          %{"Items" => [latest_msg | _]} ->
            Logger.info("📝 최신 메시지: #{inspect(latest_msg, pretty: true, limit: :infinity)}")

            sequence = case latest_msg["sequence"] do
              %{"N" => seq} -> String.to_integer(seq)
              seq when is_integer(seq) -> seq
              seq when is_binary(seq) -> String.to_integer(seq)
              _ -> 0
            end
            Logger.info("🔢 추출된 sequence: #{sequence}")

            RedisClient.set("#{Rambo.Redis.RedisMessageStore.redis_room_max_sequence_key()}:#{room_id}", to_string(sequence))
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
