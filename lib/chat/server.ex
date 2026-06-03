defmodule Chat.Server do
  use GenServer

  require Logger

  def start_link(port) do
    GenServer.start_link(
      __MODULE__,
      port,
      name: __MODULE__
    )
  end

  @impl true
  def init(port) do
    send(self(), :listen)

    {:ok, port}
  end

  @impl true
  def handle_info(:listen, port) do
    opts = [
      :binary,
      packet: :line,
      active: false,
      reuseaddr: true
    ]

    {:ok, listen_socket} =
      :gen_tcp.listen(port, opts)

    Logger.info("Listening on #{port}")

    accept_loop(listen_socket)

    {:noreply, port}
  end

  defp accept_loop(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)

    {:ok, pid} =
      DynamicSupervisor.start_child(
        Chat.ConnectionSupervisor,
        {Chat.Connection, socket}
      )

    :ok =
      :gen_tcp.controlling_process(
        socket,
        pid
      )

    accept_loop(listen_socket)
  end
end
