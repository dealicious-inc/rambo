defmodule RamboWeb.ChatController do
  use RamboWeb, :controller

  plug :put_layout, {RamboWeb.Layouts, :chat} when action in [:index]

  def index(conn, _params) do
    user = %{id: 1, name: "TestUser"} # 예시 사용자
    render(conn, "chat.html", current_user: user)
  end

  def rooms(conn, _params) do
    render(conn, "room.html")
  end

  def lobby(conn, _params) do
    render(conn, "lobby.html", page: "lobby")
  end
end
