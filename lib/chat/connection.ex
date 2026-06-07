defmodule Chat.Connection do
  use GenServer

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    Registry.register(ChatRegistry, :room, nil)
    :inet.setopts(socket, active: true)

    :gen_tcp.send(socket, "Enter your nickname:\n")

    {:ok, %{socket: socket, buffer: "", nick: ""}}
  end

  @impl true
  def handle_info({:tcp, _socket, data}, state) do
    new_buffer = state.buffer <> data
    parts = String.split(new_buffer, "\n")
    complete_messages = Enum.drop(parts, -1)
    remaining_buffer = List.last(parts) || ""

    case {state.nick, complete_messages} do
      {"", [nick | rest]} ->
        Enum.each(rest, fn msg ->
          broadcast("#{nick}: #{msg}\n")
        end)

        {:noreply, %{state | nick: nick, buffer: remaining_buffer}}

      _ ->
        Enum.each(complete_messages, fn msg ->
          broadcast("#{state.nick}: #{msg}\n")
        end)

        {:noreply, %{state | buffer: remaining_buffer}}
    end
  end

  defp broadcast(message) do
  Registry.dispatch(ChatRegistry, :room, fn entries ->
    for {pid, _} <- entries, pid != self() do
      send(pid, {:broadcast, message})
    end
  end)
end

  @impl true
  def handle_info({:broadcast, data}, state) do
    :gen_tcp.send(state.socket, data)

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    if state.nick != "" do
      Registry.dispatch(ChatRegistry, :room, fn entries ->
        for {pid, _} <- entries, pid != self() do
          send(pid, {:broadcast, "#{state.nick} has left the chat server.\n"})
        end
      end)
    end

    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, state) do
    {:stop, reason, state}
  end
end
