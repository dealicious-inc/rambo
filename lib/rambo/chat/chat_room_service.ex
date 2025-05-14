defmodule Rambo.Chat.ChatRoomService do
  @moduledoc """
  ChatRoom 생성, 참여, 읽음 처리 등 채팅방 관련 서비스 로직
  """

  alias Rambo.Repo
  alias Rambo.Chat.ChatRoom

  def get_room_by_id(room_id) do
    case Repo.get(ChatRoom, room_id) do
      nil -> {:error, "Room not found"}
      room -> {:ok, room}
    end
  end

end