defmodule RamboWeb.TalkController do
  use RamboWeb, :controller

  def index(conn, _params) do
    render(conn, :index, layout: false)
  end
end
