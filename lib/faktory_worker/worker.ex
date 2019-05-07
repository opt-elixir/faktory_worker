defmodule FaktoryWorker.Worker do
  @moduledoc false

  require Logger

  alias FaktoryWorker.ConnectionManager
  alias FaktoryWorker.WorkerLogger
  alias FaktoryWorker.ErrorFormatter

  @type t :: %__MODULE__{}

  @five_seconds 5_000
  @faktory_default_reserve_for 1800

  defstruct [
    :conn_pid,
    :disable_fetch,
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
    queues = Keyword.fetch!(opts, :queues)
    retry_interval = Keyword.get(opts, :retry_interval, @five_seconds)
    disable_fetch = Keyword.get(opts, :disable_fetch, false)

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
      queues: queues,
      faktory_name: faktory_name,
      retry_interval: retry_interval
    }
    |> schedule_fetch()
  end

  @spec send_end(state :: __MODULE__.t()) :: __MODULE__.t()
  def send_end(%{conn_pid: conn_pid} = state) when is_pid(conn_pid) do
    # only attempt to send the end command if there is a chance
    # the connection is still available
    if Process.alive?(conn_pid) do
      conn_pid
      |> send_command(:end)
      |> handle_end_response(state)
    else
      handle_end_response({:ok, :closed}, state)
    end
  end

  def send_end(state), do: state

  @spec send_fetch(state :: __MODULE__.t()) :: state :: __MODULE__.t()
  def send_fetch(%{worker_state: worker_state} = state) when worker_state == :ok do
    state.conn_pid
    |> send_command({:fetch, state.queues})
    |> handle_fetch_response(state)
    |> schedule_fetch()
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
    state.conn_pid
    |> send_command({:ack, state.job_id})
    |> handle_ack_response(:ok, state)
  end

  def ack_job(state, {:error, reason}) do
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

  defp handle_end_response({:ok, :closed}, state) do
    %{state | worker_state: :ended, conn_pid: nil}
  end

  defp handle_fetch_response({:ok, :no_content}, state), do: state

  defp handle_fetch_response({:ok, job}, state) do
    job_supervisor = job_supervisor_name(state)

    job_module =
      job["jobtype"]
      |> String.split(".")
      |> Enum.map(&String.to_atom/1)
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

  defp handle_fetch_response({:error, reason}, state) do
    WorkerLogger.log_fetch(:error, state.process_wid, reason)
    Process.sleep(state.retry_interval)
    state
  end

  defp schedule_fetch(%{disable_fetch: true} = state), do: state

  defp schedule_fetch(%{worker_state: worker_state} = state) when worker_state == :ok do
    :ok = Process.send(self(), :fetch, [])
    state
  end

  defp schedule_fetch(state), do: state

  defp handle_ack_response({:ok, _}, ack_type, state) do
    WorkerLogger.log_ack(ack_type, state.job_id, state.job["args"])
    cancel_timer(state.job_timeout_ref)

    schedule_fetch(%{
      state
      | worker_state: :ok,
        job_timeout_ref: nil,
        job_ref: nil,
        job_id: nil,
        job: nil
    })
  end

  defp handle_ack_response({:error, _}, ack_type, state) do
    WorkerLogger.log_failed_ack(ack_type, state.job_id, state.job["args"])
    cancel_timer(state.job_timeout_ref)

    schedule_fetch(%{
      state
      | worker_state: :ok,
        job_timeout_ref: nil,
        job_ref: nil,
        job_id: nil,
        job: nil
    })
  end

  defp job_supervisor_name(%{faktory_name: faktory_name}) do
    FaktoryWorker.JobSupervisor.format_supervisor_name(faktory_name)
  end

  defp cancel_timer(nil), do: :ok

  defp cancel_timer(timer_ref) do
    Process.cancel_timer(timer_ref)
  end

  defp send_command(conn_pid, command) do
    ConnectionManager.Server.send_command(conn_pid, command)
  end
end
