defmodule Rambo.Talk.MessageService do
  @moduledoc "채팅 메시지 도메인 로직 처리 모듈"

  alias Rambo.Talk.MessageStore
  alias Rambo.Nats.JetStream

  require Logger

  def send_message(conn, %{"room_id" => room_id, "sender_id" => sender_id, "message" => message}) do
    # room_id로 채팅방 정보를 조회
    with {:ok, room} <- TalkRoomService.get_room_by_id(room_id) do
      Logger.info("Room found: #{inspect(room)}")  # 채팅방 정보 로깅

      # 채팅방의 ddb_id를 사용하여 메시지 저장
      with {:ok, item} <- MessageStore.store_message(%{
        room_id: room_id,
        sender_id: sender_id,
        message: message,
        ddb_id: room.ddb_id  # ddb_id를 room 정보에서 가져옴
      }) do
        Logger.info("Message stored successfully: #{inspect(item)}")  # 메시지 저장 성공 로깅

        # JetStream에 메시지 발행
        JetStream.publish("talk.room.#{room_id}", Jason.encode!(item))
        Logger.info("Message published to JetStream: talk.room.#{room_id}")  # JetStream 발행 로깅

        {:ok, item}
      else
        error ->
          Logger.error("Failed to store the message. Error: #{inspect(error)}")  # 메시지 저장 실패 로깅
          error
      end
    else
      error ->
        Logger.error("Failed to find room with room_id: #{room_id}. Error: #{inspect(error)}")  # 채팅방 조회 실패 로깅
        error
    end
  end

  def fetch_recent_messages(room_id, opts \\ []) do
    MessageStore.get_messages(room_id, opts)
  end

  def mark_as_read(room_id, user_id, last_read_key) do
    Rambo.TalkRoomService.mark_as_read(room_id, user_id, last_read_key)
  end

  def count_unread_messages(room_id, user_id) do
    case Rambo.TalkRoomService.get_last_read_key(room_id, user_id) do
      {:ok, last_read_key} ->
        Rambo.Talk.MessageStore.count_messages_after(room_id, last_read_key)

      :not_found ->
        # 한번도 읽은 적 없으면 전체 메시지 수
        Rambo.Talk.MessageStore.count_all_messages(room_id)
    end
  end
end