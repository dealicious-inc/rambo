defmodule Rambo.Talk.RoomManager do
  alias Rambo.Talk.Subscriber

  def subscribe_all_rooms do
    room_ids = get_all_room_ids()
    Enum.each(room_ids, &Subscriber.subscribe_room/1)
  end

  defp get_all_room_ids do
#    Rambo.Repo.all(from r in Rambo.ChatRoom, select: r.id)
  end
end