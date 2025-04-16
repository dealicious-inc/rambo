defmodule Rambo.Nats.Starter do
  def start_link(_args) do
    Task.start_link(fn -> subscribe_all_rooms() end)
  end

  defp subscribe_all_rooms do
    room_ids = Rambo.Chat.ChatRoomRepo.all_room_ids()
               |> Enum.map(&to_string/1)

    Enum.each(room_ids, fn room_id ->
      Rambo.Nats.subscribe(room_id)
    end)

    Rambo.Nats.listen_loop()
  end
end