defmodule FaktoryWorker.PushPipeline.Acknowledger do
  @moduledoc false

  alias FaktoryWorker.Job
  alias FaktoryWorker.WorkerLogger

  @behaviour Broadway.Acknowledger

  @impl true
  def ack(_ack_ref, _successful_messages, failed_messages) do
    Enum.each(failed_messages, &handle_failed_message/1)
  end

  defp handle_failed_message(%{status: {:failed, :not_unique}, data: {_, job}}) do
    WorkerLogger.log_not_unique_job(job.jid, job.args, job.jobtype)
  end

  defp handle_failed_message(%{data: {pipeline, payload}}) do
    Job.perform_async(pipeline, payload, [])
  end
end
