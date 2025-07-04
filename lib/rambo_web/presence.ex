defmodule RamboWeb.Presence do
  use Phoenix.Presence,
    otp_app: :rambo,
    pubsub_server: Rambo.PubSub
end
