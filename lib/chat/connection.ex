defmodule Chat.Connection do
  use GenServer

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    :inet.setopts(socket, active: true)

    :gen_tcp.send(socket, "Welcome! Type '1' to create a room, or '2' to join a room: \n")

    {:ok, %{socket: socket, buffer: "", nick: nil, mode: :choosing, room_pid: nil}}
  end

  # ask for mode, save mode, check first line, if mode is join, take the code, add to that room, then back to the nickname process before they start chatting.

  @impl true
  def handle_info({:tcp, _socket, data}, state) do
    new_buffer = state.buffer <> data
    parts = String.split(new_buffer, "\n")
    complete_messages = Enum.drop(parts, -1)
    remaining_buffer = List.last(parts) || ""

    new_state =
      Enum.reduce(complete_messages, state, fn line, current_state ->
        process_line(String.trim(line), current_state)
      end)

    {:noreply, %{new_state | buffer: remaining_buffer}}
  end

  defp process_line("1", %{mode: :choosing} = state) do
    room_code = for(_ <- 1..6, into: "", do: <<Enum.random(?A..?Z)>>)

    # starts room 
    {:ok, room_pid} = Chat.RoomSupervisor.start_room(room_code, self())

    # supervise the pid process ?

    :ok = Chat.RoomRegistry.register_room(room_code, room_pid)

    :ok = Chat.Room.join(room_pid, self())

    :gen_tcp.send(state.socket, "Room created! Code: #{room_code}\nEnter your nickname:\n")

    # Advance the state machine to :naming and save the room_pid
    %{state | mode: :naming, room_pid: room_pid}
  end

  @impl true
  def handle_info(:room_closed, state) do
    :gen_tcp.send(state.socket, "The room host has closed the room. Goodbye!\n")
    {:stop, :normal, state}
  end

  defp process_line("2", %{mode: :choosing} = state) do
    :gen_tcp.send(state.socket, "Enter room code:\n")

    # Advance the state machine to :entering_code
    %{state | mode: :entering_code}
  end

  defp process_line(_invalid, %{mode: :choosing} = state) do
    :gen_tcp.send(state.socket, "Invalid choice. Type '1' to Create or '2' to Join:\n")
    state
  end

  defp process_line(room_code, %{mode: :entering_code} = state) do
    # Look up the code in our global directory phone book
    case Chat.RoomRegistry.lookup_room(room_code) do
      room_pid when is_pid(room_pid) ->
        # Room found! Join it.
        :ok = Chat.Room.join(room_pid, self())
        :gen_tcp.send(state.socket, "Room joined successfully!\nEnter your nickname:\n")

        # Advance the state machine to :naming and save the room_pid
        %{state | mode: :naming, room_pid: room_pid}

      nil ->
        # Room not found. Keep them in this state to try again.
        :gen_tcp.send(state.socket, "Invalid room code. Try again:\n")
        state
    end
  end

  defp process_line(nick, %{mode: :naming} = state) do
    # Tell the room process to notify everyone else that we arrived
    Chat.Room.broadcast(state.room_pid, "#{nick} joined the room!\n", self())

    :gen_tcp.send(state.socket, "Welcome to the room, #{nick}!\n")

    # Advance the state machine to :chatting and save their chosen nickname
    %{state | mode: :chatting, nick: nick}
  end

  defp process_line(msg, %{mode: :chatting} = state) do
    # Directly forward the message payload to the isolated Room process
    Chat.Room.broadcast(state.room_pid, "#{state.nick}: #{msg}\n", self())

    state
  end

  @impl true
  def handle_info({:broadcast, data}, state) do
    # Save cursor, move to beginning of line, clear line, print message, restore cursor
    :gen_tcp.send(state.socket, "\r\e[2K" <> data <> "\r")

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    if state.nick != nil and state.room_pid != nil do
      Chat.Room.broadcast(state.room_pid, "#{state.nick} has left the chat.\n", self())
    end

    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, state) do
    {:stop, reason, state}
  end
end
