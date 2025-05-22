defmodule Rambo.Nats.JetStream do

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

  def subscribe(subject, pid) when is_pid(pid) do
    Gnat.sub(:gnat, pid, subject)
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