defmodule FaktoryWorker.Worker.HeartbeatServer do
  @moduledoc false

  use GenServer

  alias FaktoryWorker.WorkerLogger
  alias FaktoryWorker.ConnectionManager

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: name_from_opts(opts))
  end

  @spec child_spec(opts :: keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: name_from_opts(opts),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    state = %{
      process_wid: Keyword.get(opts, :process_wid),
      beat_interval: Keyword.get(opts, :beat_interval, 15_000),
      beat_state: :ok,
      beat_ref: nil,
      conn: nil
    }

    {:ok, state, {:continue, {:setup_connection, opts}}}
  end

  @impl true
  def handle_continue({:setup_connection, opts}, state) do
    conn =
      opts
      |> Keyword.get(:connection, [])
      |> Keyword.put(:is_worker, true)
      |> Keyword.put(:process_wid, state.process_wid)
      |> ConnectionManager.new()

    {:noreply, %{state | conn: conn}, {:continue, :schedule_beat}}
  end

  def handle_continue(:schedule_beat, state) do
    beat_ref = Process.send_after(self(), :beat, state.beat_interval)

    {:noreply, %{state | beat_ref: beat_ref}}
  end

  @impl true
  def handle_info(:beat, %{conn: conn, process_wid: process_wid, beat_state: beat_state} = state)
      when beat_state in [:ok, :quiet] do
    state =
      conn
      |> ConnectionManager.send_command({:beat, process_wid})
      |> handle_beat_response(state)

    {:noreply, state, {:continue, :schedule_beat}}
  end

  def handle_info(:beat, state) do
    {:noreply, %{state | beat_ref: nil}, {:continue, :schedule_beat}}
  end

  @impl true
  def terminate(_reason, %{conn: conn, beat_ref: beat_ref}) when is_reference(beat_ref) do
    Process.cancel_timer(beat_ref)
    send_end(conn)
  end

  def terminate(_reason, %{conn: conn}) do
    send_end(conn)
  end

  defp send_end(nil), do: :ok

  defp send_end(conn) do
    ConnectionManager.send_command(conn, :end)
  end

  defp handle_beat_response({{:ok, %{"state" => new_beat_state}}, conn}, state) do
    # todo: need to propigate the state change to all connections
    WorkerLogger.log_beat(:ok, state.beat_state, state.process_wid)
    new_beat_state = String.to_existing_atom(new_beat_state)

    %{state | beat_state: new_beat_state, conn: conn, beat_ref: nil}
  end

  defp handle_beat_response({{result, _}, conn}, state) when result in [:ok, :error] do
    WorkerLogger.log_beat(result, state.beat_state, state.process_wid)

    %{state | beat_state: result, conn: conn, beat_ref: nil}
  end

  defp name_from_opts(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    :"#{name}_heartbeat_server"
  end
end
