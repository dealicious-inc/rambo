defmodule RamboWeb.Router do
  use RamboWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RamboWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RamboWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/chat", ChatController, :index
    get "/rooms", ChatController, :rooms
  end

  scope "/api", RamboWeb.Api do
    pipe_through :api

    get "/rooms", RoomController, :index
    post "/rooms", RoomController, :create
    post "/rooms/send-messages", RoomController, :send_message

    get "/users", UserController, :index
    post "/users", UserController, :create

    get "/talk_rooms", TalkRoomController, :index
    post "/talk_rooms", TalkRoomController, :create
    post "/talk_rooms/private", TalkRoomController, :private
    post "/talk_rooms/:id/join", TalkRoomController, :join
    get "/talk_rooms/participate-list", TalkRoomController, :participate_list
    post "/talk_rooms/:id/messages", TalkRoomController, :send_message
    get "/talk_rooms/:id/messages", TalkRoomController, :messages
    post "/talk_rooms/:id/mark_as_read", TalkRoomController, :mark_as_read
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rambo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: RamboWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
