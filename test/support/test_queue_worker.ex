defmodule FaktoryWorker.TestQueueWorker do
  @moduledoc false
  use FaktoryWorker.Job, queue: "test_queue"
end
