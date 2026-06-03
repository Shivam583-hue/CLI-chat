defmodule Chat.Connection do
  use GenServer

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    Registry.register(ChatRegistry, :room, nil)
    :inet.setopts(socket, active: true)

    {:ok, socket}
  end

  @impl true
  def handle_info({:tcp, socket, data}, socket) do
    Registry.dispatch(ChatRegistry, :room, fn entries ->
      for {pid, _} <- entries, pid != self(), do: send(pid, {:broadcast, data})
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:broadcast, data}, socket) do
    :gen_tcp.send(socket, data)

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
