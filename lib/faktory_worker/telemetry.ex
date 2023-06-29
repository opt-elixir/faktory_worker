defmodule FaktoryWorker.Telemetry do
  @moduledoc false

  require Logger

  @events [
    :push,
    :beat,
    :fetch,
    :ack,
    :failed_ack,
    :job_timeout,
    :batch_new,
    :batch_open,
    :batch_commit
  ]

  @doc false
  @spec attach_default_handler :: :ok | {:error, :already_exists}
  def attach_default_handler() do
    events = Enum.map(@events, &[:faktory_worker, &1])

    :telemetry.attach_many(:faktory_worker_logger, events, &__MODULE__.handle_event/4, [])
  end

  @doc false
  @spec execute(event :: atom(), outcome :: term(), metadata :: map()) :: :ok
  def execute(event, outcome, metadata) do
    :telemetry.execute(
      [:faktory_worker, event],
      %{status: outcome},
      metadata
    )
  end

  @doc false
  def handle_event([:faktory_worker, event], measurements, metadata, _config) do
    log_event(event, measurements, metadata)
  end

  # Push events

  defp log_event(:push, %{status: :ok}, job) do
    log(:info, "Enqueued", job.jid, job.args, job.jobtype, job.queue)
  end

  defp log_event(:push, %{status: {:error, :not_unique}}, job) do
    log(:warn, "NOTUNIQUE", job.jid, job.args, job.jobtype, job.queue)
  end

  defp log_event(:push, %{status: {:error, :timeout}}, job) do
    log(:info, "Push Timeout", job.jid, job.args, job.jobtype, job.queue)
  end

  # Beat events

  # no state change, status == status
  defp log_event(:beat, %{status: status}, %{prev_status: status}) do
    :ok
  end

  defp log_event(:beat, %{status: :ok}, %{wid: wid}) do
    log(:info, "Heartbeat Succeeded", wid)
  end

  defp log_event(:beat, %{status: :error}, %{wid: wid}) do
    log(:warn, "Heartbeat Failed", wid)
  end

  # Fetch events

  defp log_event(:fetch, %{status: {:error, reason}}, %{wid: wid}) do
    log(:info, "Failed to fetch job due to '#{reason}'", wid)
  end

  # Acks

  defp log_event(:ack, %{status: :ok}, job) do
    duration = format_duration(job.duration)
    log(:info, "Succeeded after #{duration}", job.jid, job.args, job.jobtype, job.queue)
  end

  defp log_event(:ack, %{status: :error}, job) do
    duration = format_duration(job.duration)
    log(:error, "Failed after #{duration}", job.jid, job.args, job.jobtype, job.queue)
  end

  # Failed acks

  defp log_event(:failed_ack, %{status: :ok}, job) do
    log(
      :warn,
      "Error sending 'ACK' acknowledgement to faktory",
      job.jid,
      job.args,
      job.jobtype,
      job.queue
    )
  end

  defp log_event(:failed_ack, %{status: :error}, job) do
    log(
      :error,
      "Error sending 'FAIL' acknowledgement to faktory",
      job.jid,
      job.args,
      job.jobtype,
      job.queue
    )
  end

  # Misc events

  defp log_event(:job_timeout, _, job) do
    log(
      :error,
      "Job has reached its reservation timeout and will be failed",
      job.jid,
      job.args,
      job.jobtype,
      job.queue
    )
  end

  # Log formats

  defp log(:info, message), do: Logger.info("[faktory-worker] #{message}")
  defp log(:warn, message), do: Logger.warning("[faktory-worker] #{message}")
  defp log(:error, message), do: Logger.error("[faktory-worker] #{message}")

  defp log(level, outcome, wid) do
    log(level, "#{outcome} wid-#{wid}")
  end

  defp log(level, outcome, jid, args, worker_module, "default") do
    log(level, "#{outcome} (#{worker_module}) jid-#{jid} #{inspect(args)}")
  end

  defp log(level, outcome, jid, args, worker_module, queue) do
    log(level, "#{outcome} (#{worker_module}) [#{queue}] jid-#{jid} #{inspect(args)}")
  end

  defp format_duration(ms) when ms < 1_000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{ms / 1_000}s"

  defp format_duration(ms) when ms < 3_600_000 do
    minutes = ms / 1_000 / 60
    m = floor(minutes)
    rest = round((minutes - m) * 60 * 1_000)
    "#{m}m #{format_duration(rest)}"
  end

  defp format_duration(ms) do
    hours = ms / 1_000 / 60 / 60
    h = floor(hours)
    rest = round((hours - h) * 60 * 60 * 1_000)
    "#{h}h #{format_duration(rest)}"
  end
end
