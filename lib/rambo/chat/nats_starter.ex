defmodule Rambo.Chat.NatsStarter do
  def start_link(_args) do
    Task.start_link(fn -> subscribe_all_rooms() end)
  end

  defp subscribe_all_rooms do
    room_ids = Rambo.Chat.ChatRoomRepo.all_room_ids()
               |> Enum.map(&to_string/1)  # <- 여기가 중요!

    Enum.each(room_ids, fn room_id ->
      Rambo.Chat.Nats.subscribe(room_id)
    end)

    Rambo.Chat.Nats.listen_loop()
  end
end