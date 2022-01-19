defmodule FaktoryWorker.JobIntegrationTest do
  use ExUnit.Case

  import FaktoryWorker.FaktoryTestHelpers

  alias FaktoryWorker.Job
  alias FaktoryWorker.Random
  alias FaktoryWorker.DefaultWorker

  setup :flush_faktory!

  describe "perform_async/2" do
    test "should send a new job to faktory" do
      faktory_name = :"Test_#{Random.string()}"

      start_supervised!(
        {FaktoryWorker, name: faktory_name, pool: [size: 1], worker_pool: [disable_fetch: true]}
      )

      opts = [faktory_name: faktory_name]

      job = Job.build_payload(DefaultWorker, %{hey: "there!"}, opts)

      {:ok, job_sent} = Job.perform_async(job, opts)
      assert job_sent == job

      assert_queue_size("default", 1)

      :ok = stop_supervised(faktory_name)
    end
  end
end
