defmodule FaktoryWorker.PushPipeline.Acknowledger do
  @moduledoc false

  alias FaktoryWorker.Job

  @behaviour Broadway.Acknowledger

  @impl true
  def ack(_ack_ref, _successful_messages, failed_messages) do
    Enum.each(failed_messages, fn %{data: {pipeline, payload}} ->
      Job.perform_async(pipeline, payload, [])
    end)

    :ok
  end
end
