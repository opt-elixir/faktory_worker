defmodule FaktoryWorker.PushPipeline.Acknowledger do
  @moduledoc false

  @behaviour Broadway.Acknowledger

  @impl true
  def ack(_ack_ref, _successful_messages, _failed_messages) do
    # need to work out what this should do
    :ok
  end
end
