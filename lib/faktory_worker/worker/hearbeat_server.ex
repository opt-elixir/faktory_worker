defmodule FaktoryWorker.Worker.HeartbeatServer do
  @moduledoc false

  use GenServer

  alias FaktoryWorker.EventDispatcher
  alias FaktoryWorker.ConnectionManager
  alias FaktoryWorker.Worker.Server
  alias FaktoryWorker.Worker.Pool

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
      name: Keyword.get(opts, :name),
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
  def terminate(:shutdown, %{conn: conn, beat_ref: beat_ref} = state)
      when is_reference(beat_ref) do
    Process.cancel_timer(beat_ref)
    disable_connections(state.name)
    send_end(conn)
  end

  def terminate(:shutdown, %{conn: conn} = state) do
    disable_connections(state.name)
    send_end(conn)
  end

  def terminate(_, _), do: :ok

  defp handle_beat_response({{:ok, %{"state" => new_beat_state}}, conn}, state) do
    EventDispatcher.dispatch_event(:beat, :ok, %{
      prev_status: state.beat_state,
      wid: state.process_wid
    })

    new_beat_state = String.to_existing_atom(new_beat_state)

    if new_beat_state == :quiet do
      disable_connections(state.name)
    end

    %{state | beat_state: new_beat_state, conn: conn, beat_ref: nil}
  end

  defp handle_beat_response({{result, _}, conn}, state) when result in [:ok, :error] do
    EventDispatcher.dispatch_event(:beat, result, %{
      prev_status: state.beat_state,
      wid: state.process_wid
    })

    %{state | beat_state: result, conn: conn, beat_ref: nil}
  end

  defp disable_connections(name) do
    pool_name = Pool.format_worker_pool_name(name: name)

    if is_pid(Process.whereis(pool_name)) do
      pool_name
      |> Supervisor.which_children()
      |> Enum.each(&disable_connection/1)
    end
  end

  defp disable_connection({_, worker_pid, _, _}) do
    Server.disable_fetch(worker_pid)
  end

  defp send_end(nil), do: :ok

  defp send_end(conn) do
    ConnectionManager.send_command(conn, :end)
  end

  defp name_from_opts(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    :"#{name}_heartbeat_server"
  end
end
