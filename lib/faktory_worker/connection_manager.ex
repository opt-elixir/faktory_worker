defmodule FaktoryWorker.ConnectionManager do
  @moduledoc false

  use GenServer

  alias FaktoryWorker.Connection

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def send_command(connection, command) do
    GenServer.call(connection, {:send_command, command})
  end

  @impl true
  def init(opts) do
    {:ok, connection} = FaktoryWorker.Connection.open(opts)
    {:ok, %{conn: connection}}
  end

  @impl true
  def handle_call({:send_command, command}, _, %{conn: connection} = state) do
    result = Connection.send_command(connection, command)

    {:reply, result, state}
  end
end
