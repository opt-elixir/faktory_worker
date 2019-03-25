defmodule FaktoryWorker.PushPipeline.Consumer do
  @moduledoc false

  @behaviour Broadway

  # todo: this is where we will fetch a connection from the pool and push
  #       jobs to faktory

  @impl true
  def handle_batch(_, messages, _batch_info, _context) do
    messages
  end

  @impl true
  def handle_message(_processor_name, message, _context) do
    message
  end
end
