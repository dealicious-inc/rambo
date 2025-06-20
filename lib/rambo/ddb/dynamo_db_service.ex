defmodule Rambo.Ddb.DynamoDbService do
  @table "messages"
  require Logger

  alias Rambo.RedisClient
  alias Rambo.Redis.RedisMessageStore


  def get_messages(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    sort_order = Keyword.get(opts, :sort_order, :asc)
    pk = "room:#{room_id}"

    ExAws.Dynamo.query(@table,
      key_condition_expression: "pk = :pk",
      expression_attribute_values: [pk: pk],
      limit: limit,
      scan_index_forward: sort_order == :asc
    )
    |> ExAws.request()
    |> case do
      {:ok, %{"Items" => items}} ->
        parsed_items = Enum.map(items, &parse_dynamo_item/1)
        {:ok, parsed_items}

      error ->
        error
    end
  end

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
    Logger.info("pk: room:#{room_id} 다이나모에서 최대 seq 찾기 시작 #{room_id}")

    case get_messages(room_id, limit: 1, sort_order: :desc) do
      {:ok, [latest_msg | _]} ->
        Logger.info("📝 최신 메시지: #{inspect(latest_msg, pretty: true, limit: :infinity)}")

        sequence = case latest_msg["sequence"] do
          %{"N" => seq} -> String.to_integer(seq)
          seq when is_integer(seq) -> seq
          seq when is_binary(seq) -> String.to_integer(seq)
          _ -> 0
        end
        Logger.info("🔢 추출된 sequence: #{sequence}")

        RedisClient.set("#{RedisMessageStore.redis_room_max_sequence_key()}:#{room_id}", to_string(sequence))
        {:ok, sequence}

      {:ok, []} ->
        Logger.info("📭 메시지가 없습니다")
        {:ok, 0}

      {:error, reason} = error ->
        Logger.error("❌ DynamoDB 쿼리 실패: #{inspect(reason, pretty: true, limit: :infinity)}")
        error
    end
  end

  def parse_dynamo_item(item) do
    Enum.into(item, %{}, fn {key, value_map} ->
      # DynamoDB의 문자열 키를 Elixir의 아톰 키로 변환
      atom_key = String.to_atom(key)

      # 맵에서 실제 값만 추출
      # 예: %{"S" => "some_string"} -> "some_string"
      value = case value_map do
        %{"S" => str} -> str                    # String 타입
        %{"N" => num} -> String.to_integer(num) # Number 타입
        %{"BOOL" => bool} -> bool               # Boolean 타입
        _ -> Map.values(value_map) |> List.first() # 기타 타입
      end

      {atom_key, value}
    end)
  end
end
