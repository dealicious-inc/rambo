defmodule RamboWeb.RoomChannel do
  use Phoenix.Channel
  alias RamboWeb.Presence
  require Logger

  def join("room:lobby", msg, socket) do
    Process.flag(:trap_exit, true)
    :timer.send_interval(5000, :ping)
    socket = assign(socket, :name, msg["user"])
    send(self(), {:after_join, msg}) # 이게 있어야 after_join 동작함!
    {:ok, socket}
  end

  def join("room:" <> _private_subtopic, _msg, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  # 이벤트를 수신했을 때 호출되는 콜백
  # 비동기 메시지 수신 처리
  def handle_info({:after_join, msg}, socket) do
    broadcast! socket, "user:entered", %{user: msg["user"], body: "#{msg["user"]} 두둥 등장!"}
#    push socket, "join", %{status: "connected"}

    Logger.debug ">> join #{inspect socket}"
#    @example """
#    %Phoenix.Socket{
#      assigns: %{name: "dotory"},
#      channel: RamboWeb.RoomChannel,
#      channel_pid: #PID<0.700.0>,
#      endpoint: RamboWeb.Endpoint,
#      handler: RamboWeb.UserSocket,
#      id: nil,
#      joined: true,
#      join_ref: "1",
#      private: %{
#        log_handle_in: :debug,
#        log_join: :info
#      },
#      pubsub_server: Rambo.PubSub,
#      ref: nil,
#      serializer: Phoenix.Socket.V1.JSONSerializer,
#      topic: "room:lobby",
#      transport: :websocket,
#      transport_pid: #PID<0.678.0>
#    }
#    """
    # 현재 상태 추적
    # https://hexdocs.pm/phoenix/presence.html
    {:ok, _} =
      Presence.track(socket, socket.assigns.name, %{
        online_at: inspect(System.system_time(:second))
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  # GenServer의 handle_info/2와 동일한 역할을 하며, Phoenix.Channel에서도 오버라이딩 가능
  def handle_info(:ping, socket) do
    push socket, "new:msg", %{user: "SYSTEM", body: "ping"}
    {:noreply, socket}
  end

  # 클라이언트가 채널을 떠나거나 예외로 종료될 때 호출
  def terminate(reason, socket) do
    Logger.debug("> leave reason: #{inspect reason}, user: #{socket.assigns[:name]}")
    # reason: 종료 사유 (:normal, {:shutdown, :left}, :closed, {:badmatch, ...} )등
    broadcast! socket, "user:left", %{user: socket.assigns[:name], body: "#{socket.assigns[:name]} 퇴장!"}
    :ok
  end

  # 클라이언트 → 서버로 push한 이벤트 처리
  def handle_in("new:msg", msg, socket) do
    broadcast! socket, "new:msg", %{user: msg["user"], body: msg["body"]}
    {:reply, {:ok, %{msg: msg["body"]}}, assign(socket, :user, msg["user"])}
  end

  def handle_out("new:msg", payload, socket) do
    # TODO 서버 → 클라이언트 메시지 push 전에 인터셉트해서 처리할거 하기
  end
end