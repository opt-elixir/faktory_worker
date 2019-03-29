defmodule FaktoryWorker.PushPipeline.AcknowledgerIntegrationTest do
  use ExUnit.Case

  import FaktoryWorker.FaktoryTestHelpers

  alias FaktoryWorker.Job
  alias FaktoryWorker.PushPipeline.Acknowledger

  describe "ack/3" do
    test "should requeue a failed jobs" do
      faktory_name = :"Test_#{random_string()}"
      queue_name = random_string()
      pipeline_name = FaktoryWorker.PushPipeline.format_pipeline_name(faktory_name)

      job = %{hey: "there!"}
      opts = [queue: queue_name, faktory_name: faktory_name]

      payload1 = Job.build_payload(TestWorker, job, opts)
      message1 = %{data: {pipeline_name, payload1}}

      payload2 = Job.build_payload(TestWorker, job, opts)
      message2 = %{data: {pipeline_name, payload2}}

      start_supervised!({FaktoryWorker, name: faktory_name, pool: [size: 2]})

      :ok = Acknowledger.ack(:test_ref, [], [message1, message2])

      assert_queue_size(queue_name, 2)

      :ok = stop_supervised(faktory_name)
    end
  end
end
