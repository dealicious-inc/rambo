defmodule Rambo.TalkRoomUser do
  use Rambo.Schema

  schema "talk_room_users" do
    field :user_id, :integer
    field :joined_at, :naive_datetime
    field :last_read_message_key, :string
    belongs_to :talk_room, Rambo.TalkRoom

    timestamps()
  end

  def changeset(talk_room_user, attrs) do
    talk_room_user
    |> cast(attrs, [:talk_room_id, :user_id, :joined_at, :last_read_message_key])
    |> validate_required([:talk_room_id, :user_id, :joined_at])
    |> foreign_key_constraint(:talk_room_id)
    |> unique_constraint([:talk_room_id, :user_id], name: :talk_room_users_talk_room_id_user_id_index)
  end

  @doc """
  채팅방 참여자를 생성합니다. 이미 참여한 경우 무시됩니다.
  """
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  특정 채팅방의 참여자 목록을 조회합니다.
  """
  def list_by_room(talk_room_id) do
    from(u in __MODULE__, where: u.talk_room_id == ^talk_room_id)
    |> Repo.all()
  end

  @doc """
  사용자의 마지막 읽은 메시지 키를 업데이트합니다.
  """
  def update_last_read(talk_room_id, user_id, last_read_key) do
    {count, _} =
      from(u in __MODULE__,
        where: u.talk_room_id == ^talk_room_id and u.user_id == ^user_id
      )
      |> Repo.update_all(set: [last_read_message_key: last_read_key])

    {:ok, count}
  end

  @doc """
  사용자의 마지막 읽은 메시지 키를 조회합니다.
  """
  def get_last_read_key(talk_room_id, user_id) do
    from(u in __MODULE__,
      where: u.talk_room_id == ^talk_room_id and u.user_id == ^user_id,
      select: u.last_read_message_key
    )
    |> Repo.one()
    |> case do
      nil -> :not_found
      key -> {:ok, key}
    end
  end
end
