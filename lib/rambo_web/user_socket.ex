defmodule RamboWeb.UserSocket do
  use Phoenix.Socket

  # 실시간 채팅방
  channel "room:*", RamboWeb.RoomChannel

  # JetStream 기반 1:1/다대다 채팅방
  channel "talk:*", RamboWeb.TalkChannel

  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end