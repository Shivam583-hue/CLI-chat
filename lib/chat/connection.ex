defmodule Chat.Connection do
  use GenServer

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    :inet.setopts(socket, active: true)

    {:ok, socket}
  end

  @impl true
  def handle_info({:tcp, socket, data}, socket) do
    :gen_tcp.send(socket, "Echo: #{data}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, socket) do
    {:stop, :normal, socket}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, socket) do
    {:stop, reason, socket}
  end
end
