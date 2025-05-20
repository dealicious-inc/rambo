defmodule Rambo.Talk.MessageService do
  @moduledoc "채팅 메시지 도메인 로직 처리 모듈"

  alias Rambo.Talk.MessageStore

  require Logger

  def fetch_recent_messages(room_id, opts \\ []) do
    MessageStore.get_messages(room_id, opts)
  end
end