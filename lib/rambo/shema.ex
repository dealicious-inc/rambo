defmodule Rambo.Schema do
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset
      import Ecto.Query

      alias Rambo.Repo
    end
  end
end
