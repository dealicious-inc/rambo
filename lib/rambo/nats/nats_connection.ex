defmodule Rambo.Nats.Connection do
  def start_link(_opts) do
    opts = %{
      connection_settings: %{
        host: "localhost",
        port: 4222,
        tls: false,
        connection_timeout: 3000,
        no_responders: false,
        inbox_prefix: "_INBOX.",
        ssl_opts: [],
        tcp_opts: [:binary]
      }
    }

    result = Gnat.start_link(opts)

    case result do
      {:ok, pid} ->
        Process.register(pid, :gnat)
        IO.inspect(Process.whereis(:gnat), label: "IS :gnat REGISTERED AFTER MANUAL REGISTER?")
        {:ok, pid}

      error ->
        error
    end
  end

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
