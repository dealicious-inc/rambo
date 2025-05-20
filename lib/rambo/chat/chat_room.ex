defmodule Rambo.Chat.ChatRoom do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_rooms" do
    field :name, :string
    field :ddb_id, :string
    field :deleted_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end
  def changeset(chat_room, attrs) do
    chat_room
    |> cast(attrs, [:name, :deleted_at, :ddb_id])
    |> validate_required([:name, :ddb_id])
  end
end