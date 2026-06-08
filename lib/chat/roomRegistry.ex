defmodule Chat.RoomRegistry do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  def register_room(room_code, room_pid) do
    GenServer.call(__MODULE__, {:register, room_code, room_pid})
  end

  @impl true
  def handle_call({:register, room_code, room_pid}, _from, state) do
    Process.monitor(room_pid)
    new_map = Map.put(state, room_code, room_pid)
    {:reply, :ok, new_map}
  end

  def lookup_room(room_code) do
    GenServer.call(__MODULE__, {:lookup, room_code})
  end

  @impl true
  def handle_call({:lookup, room_code}, _from, state) do
    room_pid = Map.get(state, room_code)
    {:reply, room_pid, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, dead_pid, _reason}, state) do
    new_state =
      state
      |> Enum.reject(fn {_code, pid} -> pid == dead_pid end)
      |> Map.new()

    {:noreply, new_state}
  end
end
