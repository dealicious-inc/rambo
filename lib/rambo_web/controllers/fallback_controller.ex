defmodule RamboWeb.FallbackController do
  use RamboWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: RamboWeb.ErrorJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, {:validation_error, changeset}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: RamboWeb.ErrorJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, {:not_found, model}}) do
    model_name = model |> to_string() |> String.replace("_", " ")

    conn
    |> put_status(:not_found)
    |> put_view(json: RamboWeb.ErrorJSON)
    |> render(:error, message: "존재하지 않는 #{model_name}입니다.")
  end

  def call(conn, {:error, :user_deleted}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: RamboWeb.ErrorJSON)
    |> render(:error, message: "삭제된 사용자입니다.")
  end

  def call(conn, {:error, :internal_server_error}) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(json: RamboWeb.ErrorJSON)
    |> render(:error, message: "서버 오류가 발생했습니다.")
  end

  # 기타 예상치 못한 에러 처리
  def call(conn, _) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(json: RamboWeb.ErrorJSON)
    |> render(:error, message: "알 수 없는 오류가 발생했습니다.")
  end
end
