defmodule FaktoryWorker.PushPipeline.Acknowledger do
  @moduledoc false

  alias FaktoryWorker.Job
  alias FaktoryWorker.Telemetry

  @behaviour Broadway.Acknowledger

  @impl true
  def ack(_ack_ref, _successful_messages, failed_messages) do
    Enum.each(failed_messages, &handle_failed_message/1)
  end

  defp handle_failed_message(%{status: {:error, :not_unique}, data: {_, job}}) do
    Telemetry.execute(:push, {:error, :not_unique}, job)
  end

  defp handle_failed_message(%{data: {pipeline, payload}}) do
    Job.perform_async(pipeline, payload, [])
  end
end
