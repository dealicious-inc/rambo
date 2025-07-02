defmodule Rambo.Nats do
  @topic_prefix "chat.room."
  require Logger

  def publish(room, %{"user_id" => _user_id, "user_name" => _user_name, "message" => _message} = payload) do
    payload =
      payload
      |> Map.put_new("timestamp", DateTime.utc_now() |> DateTime.to_iso8601())

    encoded = Jason.encode!(payload)
    Gnat.pub(:gnat, @topic_prefix <> room, encoded)
  end

  # 룸 참여자 카운트
  def publish(topic, payload) when is_binary(topic) and is_map(payload) do
    encoded = Jason.encode!(payload)

    Gnat.pub(:gnat, topic, encoded)
  end

  def subscribe(room) do
    Gnat.sub(:gnat, self(), @topic_prefix <> room)
  end

  # 룸참여자 구독
  def subscribe(subject, handler_fn) do
    Gnat.sub(:gnat, self(), subject)

    # 별도 listener spawn
    spawn(fn -> listen_loop(handler_fn) end)
  end

  def listen_loop do
    receive do
      {:msg, %{topic: full_topic, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"message" => msg, "user_id" => user_id, "user_name" => user_name} = payload} ->
            "chat.room." <> room = full_topic
            RamboWeb.Endpoint.broadcast("room:" <> room, "new_msg", payload)
            IO.puts("[#{user_id}][#{user_name}] #{msg}")

          _ ->
            IO.puts("Received invalid JSON message: #{inspect(body)}")
        end

        listen_loop()
    end
  end

  # 룸참여자 구독 루프
  defp listen_loop(handler_fn) do
    receive do
      {:msg, msg} ->
        handler_fn.(msg)
    end

    listen_loop(handler_fn)
  end


  def subscribe_and_listen(pid, room) do
    topic = @topic_prefix <> room
    IO.inspect({:subscribe_and_listen, pid, topic}, label: "Rambo.Nats")

    # 이 pid (RoomSubscriber)로 메시지가 가게 설정
    Gnat.sub(:gnat, pid, topic)
  end

end