defmodule Rambo.Chat.ChatRoomRepo do
  import Ecto.Query
  alias Rambo.Repo
  alias Rambo.Chat.ChatRoom

  def all_room_ids do
    Repo.all(from r in ChatRoom, select: r.id)
  end
end