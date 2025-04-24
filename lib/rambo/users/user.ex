defmodule Rambo.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :deleted_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :deleted_at])
    |> validate_required([:name])
  end
end