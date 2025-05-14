defmodule Rambo.TalkRoomUser do
  use Ecto.Schema
  import Ecto.Changeset

  schema "talk_room_users" do
    belongs_to :talk_room, Rambo.TalkRoom
    field :user_id, :integer
    field :joined_at, :naive_datetime
    field :last_read_message_key, :string

    timestamps()
  end

  def changeset(talk_room_user, attrs) do
    talk_room_user
    |> cast(attrs, [:talk_room_id, :user_id, :joined_at, :last_read_message_key])
    |> validate_required([:talk_room_id, :user_id])
  end
end