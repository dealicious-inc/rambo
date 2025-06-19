defmodule Rambo.Talk.MessageStore do
  @moduledoc "DynamoDB에 채팅 메시지를 저장하고 조회하는 모듈"

  @table "messages"

  require Logger
  alias Rambo.Repo
  alias Rambo.Ddb.DynamoDbService
  alias Rambo.Redis.RedisMessageStore

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

  # def get_messages(room_id, opts \\ []) do
  #   limit = Keyword.get(opts, :limit, 20)
  #   pk = "room:#{room_id}"

  #   ExAws.Dynamo.query(@table,
  #     key_condition_expression: "pk = :pk",
  #     expression_attribute_values: [pk: pk],
  #     limit: limit,
  #     scan_index_forward: true
  #   )
  #   |> ExAws.request()
  #   |> case do
  #     {:ok, %{"Items" => items}} ->
  #       parsed_items = Enum.map(items, &parse_dynamo_item/1)
  #       {:ok, parsed_items}

  #     error ->
  #       error
  #   end
  # end

  # 안읽은 메시지갯수 가져오는 함수
  def get_unread_message_count(room, last_read_key) do
    Logger.info("""
    📝 채팅방 정보
    room #{(inspect(room))}"
    last_read_key #{(inspect(last_read_key))}"
    """)

    {:ok, room_max_seq} = RedisMessageStore.get_room_max_sequence(room.id)

    room_max_seq = room_max_seq
    Logger.info("room_max_seq: #{room_max_seq}")


    # redis에 있으면 redis에서 가져오고 없으면 rdb값보고 ddb조회해서 가져오기
    case last_read_key do
      nil -> 1
      message_id ->
        # ddb 에서 gsi써서 해당 메시지의 seq 가져오기
        {:ok, last_read_msg_seq} = DynamoDbService.get_message_sequence(room.id, message_id)

        Logger.info("GSI 쿼리 결과: #{inspect(last_read_msg_seq)}")
        room_max_seq - last_read_msg_seq
    end
  end


  defp get_ddb_id_from_sql(room_id) do
    case Repo.get(Rambo.TalkRoom, room_id) do
      nil -> nil
      room -> room.ddb_id
    end
  end
end
