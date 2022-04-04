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

  # watch for and catch exits from command that may timeout
  def send_command(connection_manager, {command_type, _} = command, timeout)
      when command_type in [:fetch, :push] do
    try do
      GenServer.call(connection_manager, {:send_command, command}, timeout)
    catch
      :exit, {:timeout, _} ->
        {:error, :timeout}
    end
  end

  def send_command(connection_manager, command, timeout) do
    GenServer.call(connection_manager, {:send_command, command}, timeout)
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
