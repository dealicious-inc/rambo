defmodule RamboWeb.ChatController do
  use RamboWeb, :controller

  def index(conn, _params) do
    render(conn, "chat.html")
  end
end