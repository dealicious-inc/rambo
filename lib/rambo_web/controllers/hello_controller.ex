defmodule RamboWeb.HelloController do
  use RamboWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end

  def show(conn, %{"messenger" => messenger}) do
    # NATS에 메시지 발행
    if Process.whereis(:gnat_conn) do
      Gnat.pub(:gnat_conn, "chat.messages", messenger)
    else
      IO.puts(":gnat_conn 미등록")
    end

    render(conn, :show, messenger: messenger)
  end
end