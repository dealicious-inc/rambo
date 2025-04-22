defmodule Rambo.TalkRoom do
  use Ecto.Schema
  import Ecto.Changeset

  schema "talk_rooms" do
    field :room_type, :string  # "private" or "group"
    field :name, :string       # nullable

    has_many :talk_room_users, Rambo.TalkRoomUser

    timestamps()
  end

  def changeset(talk_room, attrs) do
    talk_room
    |> cast(attrs, [:room_type, :name])
    |> validate_required([:room_type])
    |> validate_inclusion(:room_type, ["private", "group"])
  end
end