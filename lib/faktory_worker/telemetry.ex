defmodule FaktoryWorker.Telemetry do
  @moduledoc false

  require Logger

  @events [:push, :beat, :fetch, :ack, :failed_ack, :batch_new, :batch_open, :batch_commit]

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
    log_info("Enqueued", job.jid, job.args, job.jobtype)
  end

  defp log_event(:push, %{status: {:error, :not_unique}}, job) do
    log_info("NOTUNIQUE", job.jid, job.args, job.jobtype)
  end

  # Beat events

  # no state change, status == status
  defp log_event(:beat, %{status: status}, %{prev_status: status}) do
    :ok
  end

  defp log_event(:beat, %{status: :ok}, %{wid: wid}) do
    log_info("Heartbeat Succeeded", wid)
  end

  defp log_event(:beat, %{status: :error}, %{wid: wid}) do
    log_info("Heartbeat Failed", wid)
  end

  # Fetch events

  defp log_event(:fetch, %{status: {:error, reason}}, %{wid: wid}) do
    log_info("Failed to fetch job due to '#{reason}'", wid)
  end

  # Acks

  defp log_event(:ack, %{status: :ok}, job) do
    log_info("Succeeded", job.jid, job.args, job.jobtype)
  end

  defp log_event(:ack, %{status: :error}, job) do
    log_info("Failed", job.jid, job.args, job.jobtype)
  end

  # Failed acks

  defp log_event(:failed_ack, %{status: :ok}, job) do
    log_info("Error sending 'ACK' acknowledgement to faktory", job.jid, job.args, job.jobtype)
  end

  defp log_event(:failed_ack, %{status: :error}, job) do
    log_info("Error sending 'FAIL' acknowledgement to faktory", job.jid, job.args, job.jobtype)
  end

  # Log formats

  defp log_info(message) do
    Logger.info("[faktory-worker] #{message}")
  end

  defp log_info(outcome, wid) do
    log_info("#{outcome} wid-#{wid}")
  end

  defp log_info(outcome, jid, args, worker_module) do
    log_info("#{outcome} (#{worker_module}) jid-#{jid} #{inspect(args)}")
  end
end
