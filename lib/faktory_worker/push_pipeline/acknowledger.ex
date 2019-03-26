defmodule FaktoryWorker.PushPipeline.Acknowledger do
  @moduledoc false

  @behaviour Broadway.Acknowledger

  @impl true
  def ack(_ack_ref, successful_messages, failed_messages) do
    # need to work out what this should do
    :ok
  end
end
