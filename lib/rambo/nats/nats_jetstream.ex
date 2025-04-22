defmodule Rambo.Nats.JetStream do
#  @gnat_name :rambo_jetstream
#
#  def connect(opts \\ []) do
#    config = Keyword.merge([host: '127.0.0.1', port: 4222, name: @gnat_name], opts)
#    Gnat.start_link(config)
#  end

  def publish(subject, payload) when is_binary(payload) do
    Gnat.pub(:gnat, subject, payload)
  end

  def subscribe(subject, callback_fn) when is_function(callback_fn, 1) do
    Gnat.sub(:gnat, self(), subject)

    spawn(fn ->
      listen_loop(callback_fn)
    end)

    :ok
  end

  defp listen_loop(callback_fn) do
    receive do
      {:msg, msg} ->
        callback_fn.(msg)
        Jetstream.ack(msg)
        listen_loop(callback_fn)
    end
  end
end