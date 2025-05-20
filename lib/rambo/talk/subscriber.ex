defmodule Rambo.Talk.Subscriber do
  alias Rambo.Nats.JetStream

  def subscribe_room(room_id) do
    subject = "talk.room.#{room_id}"

    JetStream.subscribe(subject, fn msg ->
      payload = Jason.decode!(msg.body)
      RamboWeb.Endpoint.broadcast!("talk:#{room_id}", "new_msg", payload)
    end)
  end
end