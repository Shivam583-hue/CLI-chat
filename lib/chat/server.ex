defmodule Chat.Server do
  use GenServer
  require Logger

  def start(port) do
    opts = [:binary, packet: :line, active: false, reuseaddr: true]

    case :gen_tcp.listen(port, opts) do
      {:ok, listen_socket} ->
        Logger.info("Listening for TCP connections on port #{port}...")
        loop_acceptor(listen_socket)

      {:error, reason} ->
        Logger.error("Failed to listen on port #{port}: #{inspect(reason)}")
    end
  end

  defp loop_acceptor(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        # Spawn a new process to handle the client concurrently
        {:ok, _pid} = Task.start_link(fn -> serve(client_socket) end)

        # Immediately return to accepting the next connection
        loop_acceptor(listen_socket)

      {:error, reason} ->
        Logger.error("Failed to accept connection: #{inspect(reason)}")
        loop_acceptor(listen_socket)
    end
  end

  defp serve(client_socket) do
    case :gen_tcp.recv(client_socket, 0) do
      {:ok, data} ->
        Logger.info("Received: #{inspect(data)}")
        :gen_tcp.send(client_socket, "Echo: #{data}")
        # Continue reading from this client
        serve(client_socket)

      {:error, :closed} ->
        Logger.info("Client disconnected.")

      {:error, reason} ->
        Logger.error("Socket error: #{inspect(reason)}")
    end
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok}
  end
end
