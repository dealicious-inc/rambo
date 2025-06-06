defmodule Rambo.TalkRoom do
  use Ecto.Schema
  import Ecto.Changeset

  schema "talk_rooms" do
    field :room_type, :string
    field :name, :string
    field :ddb_id, :string
    field :last_activity_at, :utc_datetime
    has_many :talk_room_users, Rambo.TalkRoomUser

    timestamps()
  end

  def changeset(talk_room, attrs) do
    talk_room
    |> cast(attrs, [:room_type, :name, :ddb_id])
    |> validate_required([:name, :room_type, :ddb_id])
    |> validate_inclusion(:room_type, ["private", "group"])
  end

  defimpl Jason.Encoder do
    def encode(%Rambo.TalkRoom{id: id, room_type: room_type, name: name, inserted_at: inserted_at, updated_at: updated_at}, opts) do
      Jason.Encode.map(%{
        id: id,
        room_type: room_type,
        name: name,
        inserted_at: inserted_at,
        updated_at: updated_at
      }, opts)
    end
  end
end