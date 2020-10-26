defmodule FaktoryWorker.BatchIntegrationTest do
  use ExUnit.Case

  import FaktoryWorker.FaktoryTestHelpers

  alias FaktoryWorker.{Job, Random, DefaultWorker, Batch}
  alias FaktoryWorker.FaktoryTestHelpers
  setup :flush_faktory!

  describe "perform_async/3" do
    test "should send a new batch to faktory" do
      faktory_name = :"Test_#{Random.string()}"

      start_supervised!(
        {FaktoryWorker, name: faktory_name, pool: [size: 1], worker_pool: [disable_fetch: true]}
      )

      batch_created_size_initial = FaktoryTestHelpers.get_batch_created_size()

      opts = [faktory_name: faktory_name]

      batch =
        Batch.build_batch_new_payload(
          DefaultWorker,
          "tester",
          {%{hey: "you!"}, opts},
          {%{hey: "me!"}, opts}
        )

      Batch.perform_async_batch(batch, :batch_new, opts)

      opts = [faktory_name: faktory_name, bid: batch.bid]

      job = Job.build_payload(DefaultWorker, %{hey: "there!"}, opts)

      Job.perform_async(job, opts)
      Batch.perform_async_batch(batch.bid, :batch_commit, opts)

      batch_created_size = FaktoryTestHelpers.get_batch_created_size()

      assert batch_created_size_initial < batch_created_size

      :ok = stop_supervised(faktory_name)
    end
  end
end
