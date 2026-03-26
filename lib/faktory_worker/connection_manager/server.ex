defmodule FaktoryWorker.ConnectionManager.Server do
  @moduledoc false

  use GenServer

  alias FaktoryWorker.ConnectionManager

  @spec start_link(opts :: keyword()) :: {:ok, pid()} | :ignore | {:error, any()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec send_command(
          connection_manager :: atom() | pid(),
          command :: Protocol.protocol_command(),
          timeout :: non_neg_integer()
        ) ::
          FaktoryWorker.Connection.response()
  def send_command(connection_manager, command, timeout \\ 5000)

  # Catch exits from GenServer.call — the connection manager process may be dead
  # (:noproc), shutting down (:normal/:shutdown), or unresponsive (:timeout).
  def send_command(connection_manager, command, timeout) do
    try do
      GenServer.call(connection_manager, {:send_command, command}, timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
      :exit, {:noproc, _} -> {:error, :connection_dead}
      :exit, {:normal, _} -> {:error, :connection_dead}
      :exit, {:shutdown, _} -> {:error, :connection_dead}
    end
  end

  @impl true
  def init(opts) do
    {:ok, ConnectionManager.new(opts)}
  end

  @impl true
  def handle_call({:send_command, command}, _, state) do
    {result, state} = ConnectionManager.send_command(state, command)
    {:reply, result, state}
  end

  @impl true
  def handle_info({:ssl_closed, _}, state) do
    {:stop, :normal, %{state | conn: nil}}
  end
end
