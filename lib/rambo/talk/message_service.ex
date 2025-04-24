defmodule Rambo.Talk.MessageService do
  @moduledoc "채팅 메시지 도메인 로직 처리 모듈"

  alias Rambo.Talk.MessageStore
  alias Rambo.Nats.JetStream

  def send_message(%{
    room_id: room_id,
    sender_id: sender_id,
    message: message
  }) do

    # 메시지 저장
    with {:ok, item} <- MessageStore.store_message(%{
      room_id: room_id,
      sender_id: sender_id,
      message: message
    }) do

      # JetStream 브로드캐스트
      JetStream.publish("talk.room.#{room_id}", Jason.encode!(item))
      {:ok, item}
    else
      error -> error
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