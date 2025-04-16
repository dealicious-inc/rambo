defmodule RamboWeb.PageController do
  use RamboWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end
