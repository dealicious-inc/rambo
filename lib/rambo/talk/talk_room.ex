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

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :room_type])
    |> validate_required([:name, :room_type])
    # ddb_id는 after_insert에서 설정할 것이므로 여기서는 제외
  end

  # ddb의 pk가 될 값
  def set_ddb_id(changeset) do
    case changeset do
      %{valid?: true, data: %{id: id}} ->
        ddb_id = "talk_room##{id}"

        # ddb_id 업데이트
        changeset.data
        |> Ecto.Changeset.change(%{ddb_id: ddb_id})
        |> Repo.update()

        {:ok, changeset}

      _ ->
        {:error, changeset}
    end
  end
end
