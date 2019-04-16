defmodule FaktoryWorker.TimeoutQueueWorker do
  @moduledoc false
  use FaktoryWorker.Job,
    queue: "timeout_queue",
    reserve_for: 20

  def perform(_args) do
    Process.sleep(10_000)
  end
end
