defmodule FaktoryWorker.Worker.Server do
  @moduledoc false

  use GenServer

  alias FaktoryWorker.Worker

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

  @spec disable_fetch(GenServer.server()) :: :ok
  def disable_fetch(server) do
    GenServer.cast(server, :disable_fetch)
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    {:ok, %{}, {:continue, {:setup_connection, opts}}}
  end

  @impl true
  def handle_continue({:setup_connection, opts}, _) do
    worker = Worker.new(opts)
    {:noreply, worker}
  end

  @impl true
  def handle_cast(:disable_fetch, state) do
    {:noreply, %{state | disable_fetch: true}}
  end

  @impl true
  def handle_info(:fetch, state) do
    state = Worker.send_fetch(state)
    {:noreply, state}
  end

  def handle_info(:job_timeout, %{job_ref: nil} = state) do
    {:noreply, state}
  end

  def handle_info(:job_timeout, state) do
    Process.demonitor(state.job_ref.ref, [:flush])
    state = Worker.stop_job(state)
    {:noreply, state}
  end

  def handle_info({job_ref, _}, %{job_ref: %{ref: job_ref}} = state) when is_reference(job_ref) do
    Process.demonitor(job_ref, [:flush])
    state = Worker.ack_job(state, :ok)
    {:noreply, state}
  end

  def handle_info({fetch_ref, result}, %{fetch_ref: %{ref: fetch_ref}} = state)
      when is_reference(fetch_ref) do
    Process.demonitor(fetch_ref, [:flush])
    state = Worker.handle_fetch_response(result, state)
    {:noreply, state}
  end

  def handle_info({:DOWN, _job_ref, :process, _pid, reason}, state) do
    state = Worker.ack_job(state, {:error, reason})
    {:noreply, state}
  end

  def handle_info({:EXIT, conn_pid, _reason}, %{conn_pid: conn_pid} = state) do
    {:stop, :normal, %{state | conn_pid: nil}}
  end

  defp name_from_opts(opts) do
    Keyword.get(opts, :name, __MODULE__)
  end
end
