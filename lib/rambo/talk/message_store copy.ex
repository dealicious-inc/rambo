defmodule Rambo.Talk.MessageStore do
  @moduledoc "DynamoDB에 채팅 메시지를 저장하고 조회하는 모듈"

  @table "messages"

  require Logger
  alias Rambo.Repo

  def store_message(attrs) do
    pk = "room:#{attrs[:room_id]}"
    sk = "msg##{attrs[:timestamp]}"
    message_id = UUID.uuid4()
    timestamp_kst =
      DateTime.now!("Asia/Seoul")
      |> DateTime.truncate(:millisecond)
      |> DateTime.to_iso8601()


    sender_id =
      case attrs["sender_id"] || attrs[:sender_id] do
        nil ->
          Logger.error("Sender ID is missing in the request")
          raise "sender_id is required"

        id when is_integer(id) ->
          id

        id ->
          String.to_integer(id)
      end

    Logger.info("pk:#{pk}")
    item = %{
      "pk" => pk,
      "sk" => sk,
      "name" => attrs["name"] || attrs[:name],
      "message_id" => message_id,
      "sender_id" => sender_id,
      "content" => attrs["content"] || attrs[:content],
      "message_type" => Map.get(attrs, "message_type") || Map.get(attrs, :message_type, "text"),
      "sent_at" => timestamp_kst,
      "sequence" => attrs[:sequence]
    }

    # 로깅: 저장할 항목 출력
    Logger.info("DDB 저장할 row: #{inspect(item)}")

    # DynamoDB에 데이터를 삽입
    ExAws.Dynamo.put_item(@table, item)
    |> ExAws.request()
    |> case do
      {:ok, _} ->
        Logger.info("✅ 저장완료")
        {:ok, item}

      error ->
        Logger.error("🚨 실패 #{inspect(error)}")
        error
    end
  end

  def get_messages(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    pk = "room:#{room_id}"

    ExAws.Dynamo.query(@table,
      key_condition_expression: "pk = :pk",
      expression_attribute_values: [pk: pk],
      limit: limit,
      scan_index_forward: true
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

  def count_messages_after(room, last_read_key, user_id) do
    Logger.info("""
    📝 채팅방 정보
    room #{(inspect(room))}"
    last_read_key #{(inspect(last_read_key))}"
    """)
    # pk = "room:#{room.ddb_id}"
  end


  defp get_ddb_id_from_sql(room_id) do
    case Repo.get(Rambo.TalkRoom, room_id) do
      nil -> nil
      room -> room.ddb_id
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
