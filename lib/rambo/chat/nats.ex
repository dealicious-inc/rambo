#defmodule Rambo.Chat.Nats do
#  @moduledoc """
#  Handles chat messaging over NATS.
#  """
#
#  @topic_prefix "chat.room."
#
#  def publish(room, message) do
#    payload = %{
#      user: "anonymous", # you can make this dynamic later
#      message: message,
#      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
#    }
#
#    encoded = Jason.encode!(payload)
#    Gnat.pub(:gnat, @topic_prefix <> room, encoded)
#  end
#
#  def subscribe(room) do
#    Gnat.sub(:gnat, self(), @topic_prefix <> room)
#  end
#
#  def listen_loop do
#    receive do
#      {:msg, %{body: body}} ->
#        case Jason.decode(body) do
#          {:ok, %{"message" => msg, "user" => user} = payload} ->
#            RamboWeb.Endpoint.broadcast("room:lobby", "new_msg", payload)
#            IO.puts("[#{user}] #{msg}")
#
#          _ ->
#            IO.puts("Received invalid JSON message: #{inspect(body)}")
#        end
#
#        listen_loop()
#    end
#  end
#end