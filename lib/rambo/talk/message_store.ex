defmodule Rambo.Talk.MessageStore do
  @moduledoc "DynamoDB에 채팅 메시지를 저장하고 조회하는 모듈"

  @table "talk_messages"

  require Logger
  alias Rambo.Repo

  def store_message(attrs) do
    message_id = "MSG##{System.system_time(:millisecond)}"

    # sender_id가 문자열로 오면 정수로 변환
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

    item = %{
      "id" => attrs[:ddb_id],
      "message_id" => message_id,
      "name" => attrs["name"] || attrs[:name],
      "sender_id" => sender_id,
      "message" => attrs["message"] || attrs[:message],
      "message_type" => Map.get(attrs, "message_type") || Map.get(attrs, :message_type, "text"),
      "sent_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # 로깅: 저장할 항목 출력
    Logger.info("Attempting to store message: #{inspect(item)}")

    # DynamoDB에 데이터를 삽입
    ExAws.Dynamo.put_item(@table, item)
    |> ExAws.request()
    |> case do
      {:ok, _} ->
        Logger.info("✅ Successfully stored the message with ID: #{message_id}")
        {:ok, item}

      error ->
        Logger.error("🚨 Failed to store the message. Error: #{inspect(error)}")
        error
    end
  end

  def get_messages(room_id, opts \\ []) do
    case get_ddb_id_from_sql(room_id) do
      nil ->
        {:error, :room_not_found}

      ddb_id ->
        limit = Keyword.get(opts, :limit, 20)
        last_seen_key = Keyword.get(opts, :last_seen_key)

        query_opts =
          [
            key_condition_expression: "id = :id",
            expression_attribute_values: %{
              "id" => %{"S" => ddb_id}
            },
            scan_index_forward: false,
            limit: limit
          ] ++
            if last_seen_key do
              [
                exclusive_start_key: %{
                  "id" => %{"S" => ddb_id},
                  "message_id" => %{"S" => last_seen_key}
                }
              ]
            else
              []
            end

        ExAws.Dynamo.query("talk_messages", query_opts)
        |> ExAws.request()
        |> case do
          {:ok, %{"Items" => items}} ->
            parsed =
              Enum.map(items, fn item ->
                %{
                  room_id: item["id"]["S"],
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
  end

  def count_messages_after(room_id, last_read_key, user_id) do
    base_expr_values = %{
      rid: %{"S" => room_id},
      me: %{"N" => to_string(user_id)}
    }

    opts =
      cond do
        is_nil(last_read_key) or last_read_key == "" ->
          [
            key_condition_expression: "id = :rid",
            filter_expression: "sender_id <> :me",
            expression_attribute_values: base_expr_values,
            select: "COUNT"
          ]

        true ->
          [
            key_condition_expression: "id = :rid AND message_id > :mid",
            filter_expression: "sender_id <> :me",
            expression_attribute_values:
              Map.merge(base_expr_values, %{mid: %{"S" => last_read_key}}),
            select: "COUNT"
          ]
      end

    ExAws.Dynamo.query("talk_messages", opts)
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

  defp get_ddb_id_from_sql(room_id) do
    case Repo.get(Rambo.TalkRoom, room_id) do
      nil -> nil
      room -> room.ddb_id
    end
  end
end
