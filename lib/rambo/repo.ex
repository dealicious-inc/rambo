defmodule Rambo.Repo do
  use Ecto.Repo,
    otp_app: :rambo,
    adapter: Ecto.Adapters.MyXQL
end
