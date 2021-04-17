defmodule FaktoryWorker.Worker do
  @moduledoc false

  require Logger

  alias FaktoryWorker.ConnectionManager
  alias FaktoryWorker.Telemetry
  alias FaktoryWorker.ErrorFormatter
  alias FaktoryWorker.QueueManager

  @type t :: %__MODULE__{}

  @five_seconds 5_000
  @faktory_default_reserve_for 1800
  @default_delay 5_000

  defstruct [
    :conn_pid,
    :disable_fetch,
    :fetch_ref,
    :process_wid,
    :worker_state,
    :queues,
    :faktory_name,
    :job_ref,
    :job_id,
    :job,
    :job_timeout_ref,
    :retry_interval
  ]

  @spec new(opts :: keyword()) :: __MODULE__.t()
  def new(opts) do
    faktory_name = Keyword.get(opts, :faktory_name, FaktoryWorker)
    process_wid = Keyword.fetch!(opts, :process_wid)
    retry_interval = Keyword.get(opts, :retry_interval, @five_seconds)
    disable_fetch = Keyword.get(opts, :disable_fetch)

    # Delay connection startup to stagger worker connections. Without this
    # all workers try to connect at the same time and it can't handle the load
    delay_max = Application.get_env(:faktory_worker, :worker_startup_delay) || @default_delay
    Process.sleep(Enum.random(1..delay_max))

    {:ok, conn_pid} =
      opts
      |> Keyword.get(:connection, [])
      |> Keyword.put(:is_worker, true)
      |> Keyword.put(:process_wid, process_wid)
      |> ConnectionManager.Server.start_link()

    %__MODULE__{
      conn_pid: conn_pid,
      disable_fetch: disable_fetch,
      process_wid: process_wid,
      worker_state: :ok,
      faktory_name: faktory_name,
      retry_interval: retry_interval
    }
    |> schedule_fetch()
  end

  @spec send_fetch(state :: __MODULE__.t()) :: state :: __MODULE__.t()
  def send_fetch(%{worker_state: worker_state} = state) when worker_state == :ok do
    job_supervisor = job_supervisor_name(state)

    queues = checkout_queues(state)

    fetch_ref =
      Task.Supervisor.async_nolink(
        job_supervisor,
        fn ->
          send_command(state.conn_pid, {:fetch, queues})
        end
      )

    %{state | fetch_ref: fetch_ref, queues: queues}
  end

  def send_fetch(state), do: state

  @spec stop_job(state :: __MODULE__.t()) :: __MODULE__.t()
  def stop_job(%{job_ref: job_ref} = state) when job_ref != nil do
    state
    |> job_supervisor_name()
    |> Task.Supervisor.terminate_child(job_ref.pid)

    ack_job(state, {:error, "Job Timeout"})
  end

  def stop_job(state), do: state

  @spec ack_job(state :: __MODULE__.t(), :ok | {:error, any()}) :: __MODULE__.t()
  def ack_job(state, :ok) do
    checkin_queues(state)

    state.conn_pid
    |> send_command({:ack, state.job_id})
    |> handle_ack_response(:ok, state)
  end

  def ack_job(state, {:error, reason}) do
    checkin_queues(state)

    backtrace_length = Map.get(state.job, "backtrace", 30)

    error = ErrorFormatter.format_error(reason, backtrace_length)

    payload = %{
      jid: state.job_id,
      errtype: error.type,
      message: error.message,
      backtrace: error.stacktrace
    }

    state.conn_pid
    |> send_command({:fail, payload})
    |> handle_ack_response(:error, state)
  end

  def handle_fetch_response({:ok, job}, state) when is_map(job) do
    job_supervisor = job_supervisor_name(state)

    job_module =
      job["jobtype"]
      |> String.split(".")
      |> Module.safe_concat()

    job_ref =
      Task.Supervisor.async_nolink(
        job_supervisor,
        job_module,
        :perform,
        job["args"],
        shutdown: :brutal_kill
      )

    reserve_for_seconds = Map.get(job, "reserve_for", @faktory_default_reserve_for)

    # set a timeout for the job process of the configured reserve_for
    # time minus 20 seconds to ensure the job is stopped before faktory
    # can expire and retry it on the server
    timeout_duration = (reserve_for_seconds - 20) * 1000
    timeout_ref = Process.send_after(self(), :job_timeout, timeout_duration)

    %{
      state
      | worker_state: :running_job,
        job_timeout_ref: timeout_ref,
        job_ref: job_ref,
        job_id: job["jid"],
        job: job
    }
  end

  def handle_fetch_response({:ok, _}, state), do: schedule_fetch(state)

  def handle_fetch_response({:error, reason}, state) do
    Telemetry.execute(:fetch, {:error, reason}, %{wid: state.process_wid})
    Process.send_after(self(), :fetch, state.retry_interval)
    state
  end

  @spec checkin_queues(state :: __MODULE__.t()) :: :ok
  def checkin_queues(%{queues: nil}), do: :ok

  def checkin_queues(%{queues: queues} = state) do
    QueueManager.checkin_queues(queue_manager_name(state), queues)
  end

  defp schedule_fetch(%{disable_fetch: true} = state), do: state

  defp schedule_fetch(%{worker_state: worker_state} = state) when worker_state == :ok do
    Process.send_after(self(), :fetch, 50)
    state
  end

  defp handle_ack_response({:ok, _}, ack_type, state) do
    Telemetry.execute(:ack, ack_type, %{
      jid: state.job_id,
      args: state.job["args"],
      jobtype: state.job["jobtype"]
    })

    cancel_timer(state.job_timeout_ref)

    schedule_fetch(%{
      state
      | worker_state: :ok,
        queues: nil,
        job_timeout_ref: nil,
        job_ref: nil,
        job_id: nil,
        job: nil
    })
  end

  defp handle_ack_response({:error, _}, ack_type, state) do
    Telemetry.execute(:failed_ack, ack_type, %{
      jid: state.job_id,
      args: state.job["args"],
      jobtype: state.job["jobtype"]
    })

    cancel_timer(state.job_timeout_ref)

    schedule_fetch(%{
      state
      | worker_state: :ok,
        queues: nil,
        job_timeout_ref: nil,
        job_ref: nil,
        job_id: nil,
        job: nil
    })
  end

  defp checkout_queues(%{queues: nil} = state) do
    QueueManager.checkout_queues(queue_manager_name(state))
  end

  defp checkout_queues(%{queues: queues}), do: queues

  defp job_supervisor_name(%{faktory_name: faktory_name}) do
    FaktoryWorker.JobSupervisor.format_supervisor_name(faktory_name)
  end

  defp queue_manager_name(%{faktory_name: faktory_name}) do
    QueueManager.format_queue_manager_name(faktory_name)
  end

  defp cancel_timer(nil), do: :ok

  defp cancel_timer(timer_ref) do
    Process.cancel_timer(timer_ref)
  end

  defp send_command(conn_pid, command) do
    ConnectionManager.Server.send_command(conn_pid, command)
  end
end
