defmodule Chat.Room do
  use GenServer

  def start_link(%{room_code: room_code, creator_pid: creator_pid}) do
    GenServer.start_link(__MODULE__, %{room_code: room_code, creator_pid: creator_pid})
  end

  @impl true
  def init(%{room_code: room_code, creator_pid: creator_pid}) do
    {:ok, %{code: room_code, creator_pid: creator_pid, member_pids: []}}
  end

  def join(room_pid, client_pid) do
    GenServer.call(room_pid, {:join, client_pid})
  end

  @impl true
  def handle_call({:join, client_pid}, _from, state) do
    new_members = [client_pid | state.member_pids]
    {:reply, :ok, %{state | member_pids: new_members}}
  end

  def broadcast(room_pid, message, sender_pid) do
    GenServer.cast(room_pid, {:broadcast, message, sender_pid})
  end

  @impl true
  def handle_cast({:broadcast, message, sender_pid}, state) do
    Enum.each(state.member_pids, fn pid ->
      if pid != sender_pid do
        send(pid, {:broadcast, message})
      end
    end)

    {:noreply, state}
  end
end
