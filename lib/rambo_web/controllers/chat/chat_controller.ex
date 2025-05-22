defmodule RamboWeb.ChatController do
  use RamboWeb, :controller

  def index(conn, _params) do
    render(conn, "chat.html")
  end

  def rooms(conn, _params) do
    render(conn, "room.html")
  end

  def lobby(conn, _params) do
    render(conn, "lobby.html")
  end
end