defmodule Rambo.Talk.MessageStore do
  @moduledoc "DynamoDB에 채팅 메시지를 저장하고 조회하는 모듈"

  alias ExAws.Dynamo

  @table "talk_messages"

  # 메시지 저장
  def store_message(attrs) do
    item = %{
      "room_id" => to_string(attrs.room_id),
      "message_id" => "MSG##{System.system_time(:millisecond)}",
      "sender_id" => attrs.sender_id,
      "message" => attrs.message,
      "message_type" => Map.get(attrs, :message_type, "text"),
      "sent_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Dynamo.put_item(@table, item)
    |> ExAws.request()
    |> case do
         {:ok, _} -> {:ok, item}
         error -> error
       end
  end

  # 메시지 조회 (최근 n개)
  def get_messages(room_id, limit \\ 20) do
    Dynamo.query(@table,
      key_condition_expression: "room_id = :rid",
      expression_attribute_values: %{":rid" => room_id},
      scan_index_forward: true,
      limit: limit
    )
    |> ExAws.request()
    |> case do
         {:ok, %{"Items" => items}} -> {:ok, Enum.map(items, &Dynamo.decode!/1)}
         error -> error
       end
  end

  def count_messages_after(room_id, last_read_key) do
    ExAws.Dynamo.query("talk_messages",
      key_condition_expression: "room_id = :rid AND message_id > :mid",
      expression_attribute_values: %{
        ":rid" => room_id,
        ":mid" => last_read_key
      },
      select: "COUNT"
    )
    |> ExAws.request()
    |> case do
         {:ok, %{"Count" => count}} -> {:ok, count}
         error -> error
       end
  end

  def count_all_messages(room_id) do
    ExAws.Dynamo.query("talk_messages",
      key_condition_expression: "room_id = :rid",
      expression_attribute_values: %{":rid" => room_id},
      select: "COUNT"
    )
    |> ExAws.request()
    |> case do
         {:ok, %{"Count" => count}} -> {:ok, count}
         error -> error
       end
  end
end