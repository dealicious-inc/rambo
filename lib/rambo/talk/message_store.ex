defmodule Rambo.Talk.MessageStore do
  @moduledoc "DynamoDB에 채팅 메시지를 저장하고 조회하는 모듈"

  @table "talk_messages"

  def store_message(attrs) do
    message_id = "MSG##{System.system_time(:millisecond)}"
    sender_id = if is_integer(attrs["sender_id"] || attrs[:sender_id]), do: attrs["sender_id"] || attrs[:sender_id], else: String.to_integer("#{attrs["sender_id"] || attrs[:sender_id]}")

    item = %{
      "room_id" => String.to_integer("#{attrs["room_id"] || attrs[:room_id]}"),
      "message_id" => message_id,
      "sender_id" => sender_id,
      "message" => attrs["message"] || attrs[:message],
      "message_type" => Map.get(attrs, "message_type") || Map.get(attrs, :message_type, "text"),
      "sent_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    ExAws.Dynamo.put_item(@table, item)
    |> ExAws.request()
    |> case do
         {:ok, _} -> {:ok, item}
         error -> error
       end
  end

  def get_messages(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    last_seen_key = Keyword.get(opts, :last_seen_key)

    rid_str = to_string(room_id)

    base_opts = [
      key_condition_expression: "room_id = :rid",
      expression_attribute_values: %{
        :rid => %{"N" => rid_str}
      },
      scan_index_forward: false,
      limit: limit
    ]

    full_opts =
      if last_seen_key do
        base_opts ++ [
          exclusive_start_key: %{
            "room_id" => %{"N" => rid_str},
            "message_id" => %{"S" => last_seen_key}
          }
        ]
      else
        base_opts
      end

    ExAws.Dynamo.query("talk_messages", full_opts)
    |> ExAws.request()
    |> case do
         {:ok, %{"Items" => items}} ->
           parsed =
             Enum.map(items, fn item ->
               %{
                 room_id: item["room_id"]["N"] |> String.to_integer(),
                 sender_id: item["sender_id"]["N"] |> String.to_integer(),
                 message_id: item["message_id"]["S"],
                 message: item["message"]["S"],
                 message_type: item["message_type"]["S"],
                 sent_at: item["sent_at"]["S"]
               }
             end)

           {:ok, parsed}

         error ->
           IO.inspect(error, label: "🚨 에러")
           error
       end
  end

  def count_messages_after(room_id, last_read_key) do
    ExAws.Dynamo.query("talk_messages",
      key_condition_expression: "room_id = :rid AND message_id > :mid",
      expression_attribute_values: %{
        :rid => %{"N" => to_string(room_id)},
        :mid => %{"N" => to_string(last_read_key)}
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
      expression_attribute_values: %{
        :rid => %{"N" => to_string(room_id)}
      },
      select: "COUNT"
    )
    |> ExAws.request()
    |> case do
         {:ok, %{"Count" => count}} -> {:ok, count}
         error -> error
       end
  end

end