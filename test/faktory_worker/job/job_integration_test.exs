defmodule FaktoryWorker.JobIntegrationTest do
  use ExUnit.Case

  import FaktoryWorker.FaktoryTestHelpers

  alias FaktoryWorker.Job
  alias FaktoryWorker.Random

  describe "perform_async/3" do
    test "should send a new job to faktory" do
      faktory_name = :"Test_#{Random.string()}"
      start_supervised!({FaktoryWorker, name: faktory_name, pool: [size: 1]})

      queue_name = Random.string()

      opts = [
        queue: queue_name,
        faktory_name: faktory_name
      ]

      job = Job.build_payload(SomeWorker, %{hey: "there!"}, opts)

      Job.perform_async(job, opts)

      assert_queue_size(queue_name, 1)

      :ok = stop_supervised(faktory_name)
    end
  end
end
