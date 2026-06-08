defmodule Chat.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port =
      case System.get_env("CHAT_PORT") do
        nil -> 4040
        val -> String.to_integer(val)
      end

    children = [
      Chat.RoomSupervisor,
      Chat.RoomRegistry,
      Chat.ConnectionSupervisor,
      {Chat.Server, port}
    ]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: Chat.Supervisor
    )
  end
end
