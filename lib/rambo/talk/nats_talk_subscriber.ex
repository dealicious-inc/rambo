defmodule Rambo.Talk.Subscriber do
  alias Rambo.Nats.JetStream

  require Logger

  def subscribe_room(room_id) do
    subject = "talk.room.#{room_id}"
    JetStream.subscribe(subject)
    # Logger.info("NATS 토픽 구독 시작 ####### - #{subject}")
    # JetStream.subscribe(subject, fn msg ->
    #   case Jason.decode(msg.body) do
    #     {:ok, payload} ->
    #       RamboWeb.Endpoint.broadcast!("talk:#{room_id}", "new_msg", payload)
    #     error ->
    #       Logger.error("NATS 토픽 구독 실패 ####### - #{subject} #{inspect(error)}")
    #   end
    # end)
  end

  def subscribe_room_for_lobby(room_id, pid) do
    subject = "talk.room.#{room_id}"

    JetStream.subscribe(subject, fn _msg ->
      send(pid, {:refresh_room_list})
    end)
  end
end
