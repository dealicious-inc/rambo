defmodule RamboWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:" <> room_id, _params, socket) do
    IO.puts("Joined room: #{room_id}")
    {:ok, socket}
  end

  def handle_in("new_msg", %{"user" => user, "message" => msg}, socket) do
    broadcast!(socket, "new_msg", %{
      user: user,
      message: msg,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    {:noreply, socket}
  end
end