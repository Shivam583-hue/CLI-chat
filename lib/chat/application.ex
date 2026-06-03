defmodule Chat.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = 4040

    children = [
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
