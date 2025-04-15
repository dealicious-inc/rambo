defmodule Rambo.Chat.Nats do
  @topic_prefix "chat.room."

  def publish(room, %{"user" => user, "message" => message}) do
    payload = %{
      user: user,
      message: message,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    encoded = Jason.encode!(payload)
    IO.inspect({:publishing_to, @topic_prefix <> room}, label: "🔥 NATS PUBLISH")

    Gnat.pub(:gnat, @topic_prefix <> room, encoded)
  end

  def subscribe(room) do
    Gnat.sub(:gnat, self(), @topic_prefix <> room)
  end

  def listen_loop do
    receive do
      {:msg, %{topic: full_topic, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"message" => msg, "user" => user} = payload} ->
            "chat.room." <> room = full_topic
            RamboWeb.Endpoint.broadcast("room:" <> room, "new_msg", payload)
            IO.puts("[#{user}] #{msg}")

          _ ->
            IO.puts("Received invalid JSON message: #{inspect(body)}")
        end

        listen_loop()
    end
  end
end