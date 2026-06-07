defmodule Chat.RoomSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Call this function whenever someone says "Create Room"
  def start_room(room_code, creator_pid) do
    spec = {Chat.Room, %{room_code: room_code, creator_pid: creator_pid}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
