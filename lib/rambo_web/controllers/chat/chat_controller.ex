defmodule RamboWeb.ChatController do
  use RamboWeb, :controller

  def index(conn, _params) do
    render(conn, "chat.html", page: :chat)
  end

  def rooms(conn, _params) do
    render(conn, "room.html", page: :group_chat_list)
  end

  def lobby(conn, _params) do
    render(conn, "lobby.html", page: :lobby, routes: RamboWeb.Router.Helpers)
  end
end