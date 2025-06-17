defmodule Rambo.Talk.Subscriber do
  alias Rambo.Nats.JetStream

  # talk.room.#{room_id}로 new_msg 이벤트 브로드 캐스팅, TalkChannel에서 수신한 클라이언트가 메시지를 받게됨
  def subscribe_room(room_id) do
    subject = "talk.room.#{room_id}"
    IO.puts("🟡 [subscribe_room] Subscribing to: #{subject}")

    JetStream.subscribe(subject, fn msg ->
      IO.puts("🟢 [subscribe_room] Message received on #{subject}: #{inspect(msg.body)}")

      case Jason.decode(msg.body) do
        {:ok, payload} ->
          IO.puts("📢 [subscribe_room] Broadcasting to talk:#{room_id}")
          RamboWeb.Endpoint.broadcast!("talk:#{room_id}", "new_msg", payload)

        error ->
          IO.puts("❌ [subscribe_room] Failed to decode message: #{inspect(error)}")
      end
    end)
  end

  # 로비 화면에서 채팅방 목록을 갱신해야 할 필요가 생긴 경우에 사용
  def subscribe_room_for_lobby(room_id, pid) do
    subject = "talk.room.#{room_id}"

    JetStream.subscribe(subject, fn _msg ->
      send(pid, {:refresh_room_list})
    end)
  end
end