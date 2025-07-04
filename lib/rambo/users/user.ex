defmodule Rambo.Users.User do
  use Rambo.Schema

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

  def get_active_user(id) do
    case Repo.get(__MODULE__, id) do
      nil -> {:error, {:not_found, :user}}
      %__MODULE__{deleted_at: nil} = user -> {:ok, user}
      %__MODULE__{} -> {:error, :user_deleted}
    end
  end
end
