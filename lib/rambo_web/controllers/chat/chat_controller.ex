defmodule RamboWeb.ChatController do
  use RamboWeb, :controller

  plug :put_layout, {RamboWeb.Layouts, :chat} when action in [:index]

  def rooms(conn, _params) do
    render(conn, "room.html",
      layout: false,
      page: :room_list)
  end

  def live_chat(conn, _params) do
    render(conn, "live_chat.html",
      page: :live_chat,
      layout: false,
    )
  end

  def lobby(conn, _params) do
    render(conn, "lobby.html", page: "lobby")
  end
end
