defmodule Chat.Connection do
  use GenServer

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    Registry.register(ChatRegistry, :room, nil)
    :inet.setopts(socket, active: true)

    {:ok, %{socket: socket, buffer: ""}}
  end

  @impl true
  def handle_info({:tcp, _socket, data}, state) do
    new_buffer = state.buffer <> data
    parts = String.split(new_buffer, "\n")
    complete_messages = Enum.drop(parts, -1)
    remaining_buffer = List.last(parts) || ""

    Enum.each(complete_messages, fn msg ->
      Registry.dispatch(ChatRegistry, :room, fn entries ->
        for {pid, _} <- entries, pid != self() do
          send(pid, {:broadcast, msg <> "\n"})
        end
      end)
    end)

    {:noreply, %{state | buffer: remaining_buffer}}
  end

  @impl true
  def handle_info({:broadcast, data}, state) do
    :gen_tcp.send(state.socket, data)

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, state) do
    {:stop, reason, state}
  end
end
