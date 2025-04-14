defmodule RamboWeb.Api.SocketController do
  use RamboWeb, :controller
#  use RamboWeb.RoomChannel , :channel

  def subscribe(conn, %{"messenger" => messenger}) do
    RamboWeb.RoomChannel.join("room:lobby", "hello#{messenger}}", conn)
    render(conn, :subscribe, messenger: "chloe")
  end
end