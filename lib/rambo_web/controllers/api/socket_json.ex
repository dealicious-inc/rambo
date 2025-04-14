defmodule RamboWeb.Api.SocketJSON do
  def subscribe(assigns) do
    %{messenger: assigns[:messenger]}
  end

  def messsages(assigns) do
    %{messages: assigns[:messages]}
  end
end