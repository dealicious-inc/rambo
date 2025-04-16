defmodule RamboWeb.Api.UserController do
  use RamboWeb, :controller

  alias Rambo.Users.User
  alias Rambo.Repo

  def index(conn, _params) do
    users = Repo.all(User)
            |> Enum.map(&%{id: &1.id, name: &1.name})

    json(conn, users)
  end

  def create(conn, %{"name" => name}) do
    changeset = User.changeset(%User{}, %{name: name})

    case Repo.insert(changeset) do
      {:ok, user} ->
        json(conn, %{id: user.id, name: user.name, message: "User created"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create user", reason: changeset.errors})
    end
  end
end