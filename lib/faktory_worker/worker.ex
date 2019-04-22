defmodule FaktoryWorker.Worker do
  @moduledoc false

  require Logger

  alias FaktoryWorker.ConnectionManager
  alias FaktoryWorker.WorkerLogger
  alias FaktoryWorker.ErrorFormatter

  @type t :: %__MODULE__{}

  @fifteen_seconds 15_000
  @five_seconds 5_000
  @faktory_default_reserve_for 1800
  @valid_beat_states [:ok, :quiet, :running_job]

  defstruct [
    :conn,
    :disable_fetch,
    :worker_id,
    :worker_state,
    :worker_module,
    :worker_config,
    :job_ref,
    :job_id,
    :job_args,
    :job_timeout_ref,
    :retry_interval,
    :beat_state,
    :beat_interval,
    :beat_ref
  ]

  @spec new(opts :: keyword()) :: __MODULE__.t()
  def new(opts) do
    worker_id = Keyword.fetch!(opts, :worker_id)
    worker_module = Keyword.fetch!(opts, :worker_module)
    beat_interval = Keyword.get(opts, :beat_interval, @fifteen_seconds)
    retry_interval = Keyword.get(opts, :retry_interval, @five_seconds)
    disable_fetch = Keyword.get(opts, :disable_fetch, false)

    connection =
      opts
      |> Keyword.get(:connection, [])
      |> Keyword.put(:is_worker, true)
      |> Keyword.put(:worker_id, worker_id)
      |> ConnectionManager.new()

    %__MODULE__{
      conn: connection,
      disable_fetch: disable_fetch,
      worker_id: worker_id,
      worker_state: :ok,
      worker_module: worker_module,
      worker_config: worker_module.worker_config(),
      retry_interval: retry_interval,
      beat_state: :ok,
      beat_interval: beat_interval
    }
    |> schedule_beat()
    |> schedule_fetch()
  end

  @spec send_end(state :: __MODULE__.t()) :: __MODULE__.t()
  def send_end(%{conn: conn} = state) do
    conn
    |> ConnectionManager.send_command(:end)
    |> handle_end_response(state)
  end

  def send_end(state), do: state

  @spec send_beat(state :: __MODULE__.t()) :: __MODULE__.t()
  def send_beat(%{worker_state: worker_state} = state)
      when worker_state in @valid_beat_states do
    state.conn
    |> ConnectionManager.send_command({:beat, state.worker_id})
    |> handle_beat_response(state)
    |> clear_beat_ref()
    |> schedule_beat()
  end

  def send_beat(state), do: clear_beat_ref(state)

  @spec send_fetch(state :: __MODULE__.t()) :: state :: __MODULE__.t()
  def send_fetch(%{worker_state: worker_state} = state) when worker_state == :ok do
    queues =
      state.worker_config
      |> Keyword.get(:queue, [])
      |> format_queue_for_command()

    state.conn
    |> ConnectionManager.send_command({:fetch, queues})
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
    state.conn
    |> ConnectionManager.send_command({:ack, state.job_id})
    |> handle_ack_response(:ok, state)
  end

  def ack_job(state, {:error, reason}) do
    backtrace_length = Keyword.get(state.worker_config, :backtrace, 30)

    error = ErrorFormatter.format_error(reason, backtrace_length)

    payload = %{
      jid: state.job_id,
      errtype: error.type,
      message: error.message,
      backtrace: error.stacktrace
    }

    state.conn
    |> ConnectionManager.send_command({:fail, payload})
    |> handle_ack_response(:error, state)
  end

  defp handle_beat_response({{:ok, %{"state" => new_state}}, conn}, state) do
    new_state = String.to_existing_atom(new_state)
    WorkerLogger.log_beat(:ok, state.beat_state, state.worker_id)

    %{state | conn: conn, worker_state: new_state, beat_state: :ok}
  end

  defp handle_beat_response({{:ok, _}, conn}, state) do
    WorkerLogger.log_beat(:ok, state.beat_state, state.worker_id)

    %{state | conn: conn, beat_state: :ok}
  end

  defp handle_beat_response({{:error, _}, conn}, state) do
    WorkerLogger.log_beat(:error, state.beat_state, state.worker_id)

    %{state | conn: conn, beat_state: :error}
  end

  defp handle_end_response({_, conn}, state) do
    %{conn: nil} = ConnectionManager.close_connection(conn)
    %{state | worker_state: :ended, conn: nil}
  end

  defp clear_beat_ref(state), do: %{state | beat_ref: nil}

  defp schedule_beat(%{worker_state: worker_state} = state)
       when worker_state in @valid_beat_states do
    beat_ref = Process.send_after(self(), :beat, state.beat_interval)
    %{state | beat_ref: beat_ref}
  end

  defp schedule_beat(state), do: state

  defp handle_fetch_response({{:ok, :no_content}, conn}, state) do
    %{state | conn: conn}
  end

  defp handle_fetch_response({{:ok, job}, conn}, state) do
    job_supervisor = job_supervisor_name(state)

    job_ref =
      Task.Supervisor.async_nolink(
        job_supervisor,
        state.worker_module,
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
      | conn: conn,
        worker_state: :running_job,
        job_timeout_ref: timeout_ref,
        job_ref: job_ref,
        job_id: job["jid"],
        job_args: job["args"]
    }
  end

  defp handle_fetch_response({{:error, reason}, conn}, state) do
    WorkerLogger.log_fetch(:error, state.worker_id, reason)
    Process.sleep(state.retry_interval)
    %{state | conn: conn}
  end

  defp schedule_fetch(%{disable_fetch: true} = state), do: state

  defp schedule_fetch(%{worker_state: worker_state} = state) when worker_state == :ok do
    :ok = Process.send(self(), :fetch, [])
    state
  end

  defp schedule_fetch(state), do: state

  defp handle_ack_response({{:ok, _}, conn}, ack_type, state) do
    WorkerLogger.log_ack(ack_type, state.job_id, state.job_args)
    cancel_timer(state.job_timeout_ref)

    schedule_fetch(%{
      state
      | conn: conn,
        worker_state: :ok,
        job_timeout_ref: nil,
        job_ref: nil,
        job_id: nil,
        job_args: nil
    })
  end

  defp handle_ack_response({{:error, _}, conn}, ack_type, state) do
    WorkerLogger.log_failed_ack(ack_type, state.job_id, state.job_args)
    cancel_timer(state.job_timeout_ref)

    schedule_fetch(%{
      state
      | conn: conn,
        worker_state: :ok,
        job_timeout_ref: nil,
        job_ref: nil,
        job_id: nil,
        job_args: nil
    })
  end

  defp format_queue_for_command(queue) when is_binary(queue), do: [queue]
  defp format_queue_for_command(queues), do: queues

  defp job_supervisor_name(%{worker_config: config}) do
    config
    |> Keyword.get(:faktory_name, FaktoryWorker)
    |> FaktoryWorker.JobSupervisor.format_supervisor_name()
  end

  defp cancel_timer(nil), do: :ok

  defp cancel_timer(timer_ref) do
    Process.cancel_timer(timer_ref)
  end
end
