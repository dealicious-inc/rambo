defmodule Rambo.TalkRoom do
  use Rambo.Schema

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
  end

  @doc """
  채팅방을 생성
  """
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  채팅방의 DynamoDB ID를 설정
  """
  def set_ddb_id(%__MODULE__{} = room) do
    ddb_id = "talk_room##{room.id}"

    room
    |> Ecto.Changeset.change(%{ddb_id: ddb_id})
    |> Repo.update()
  end

  @doc """
  채팅방의 마지막 활동 시간을 업데이트합니다.
  """
  def touch_activity(room_id) do
    {count, _} =
      from(r in __MODULE__, where: r.id == ^room_id)
      |> Repo.update_all(set: [last_activity_at: DateTime.utc_now()])

    if count > 0, do: :ok, else: {:error, :not_found}
  end

  @doc """
  ID로 채팅방을 조회합니다.
  """
  def get(id) do
    case Repo.get(__MODULE__, id) do
      nil -> {:error, {:not_found, :talk_room}}
      room -> {:ok, room}
    end
  end

  @doc """
  모든 채팅방 목록을 조회합니다.
  """
  def list do
    Repo.all(__MODULE__)
  end
end
