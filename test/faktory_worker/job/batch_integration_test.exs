defmodule FaktoryWorker.BatchIntegrationTest do
  use ExUnit.Case

  import FaktoryWorker.FaktoryTestHelpers

  alias FaktoryWorker.{Job, Random, DefaultWorker, Batch}
  alias FaktoryWorker.FaktoryTestHelpers
  setup :flush_faktory!

  describe "new/2" do
    test "should send a new batch to faktory" do
      faktory_name = :"Test_#{Random.string()}"

      start_supervised!(
        {FaktoryWorker, name: faktory_name, pool: [size: 1], worker_pool: [disable_fetch: true]}
      )

      opts = [faktory_name: faktory_name]

      args = [
        on_complete: {DefaultWorker, %{hey: "you!"}, opts},
        on_success: {DefaultWorker, %{hey: "me!"}, opts}
      ]

      batch =
        Batch.build_payload(
          "tester",
          args
        )

      {:ok, bid} = Batch.new(batch, opts)

      send_job_to_faktory(%{hey: "there!", custom: %{bid: bid}}, opts)

      Batch.commit(bid, opts)

      {:ok, _} = FaktoryTestHelpers.get_batch_status(bid)

      :ok = stop_supervised(faktory_name)
    end
  end

  describe "open/2" do
    test "should open a batch in faktory" do
      faktory_name = :"Test_#{Random.string()}"

      start_supervised!(
        {FaktoryWorker, name: faktory_name, pool: [size: 1], worker_pool: [disable_fetch: true]}
      )

      opts = [faktory_name: faktory_name]

      args = [
        on_complete: {DefaultWorker, %{hey: "you!"}, opts},
        on_success: {DefaultWorker, %{hey: "me!"}, opts}
      ]

      batch =
        Batch.build_payload(
          "tester",
          args
        )

      # new batch
      {:ok, bid} = Batch.new(batch, opts)
      # job in the batch
      send_job_to_faktory(%{hey: "there!", custom: %{bid: bid}}, opts)
      # commit batch
      Batch.commit(bid, opts)

      # reopen batch
      Batch.open(bid, opts)
      # job in the batch
      send_job_to_faktory(%{hey: "in the batch!", custom: %{bid: bid}}, opts)

      # child args
      child_args = [
        on_complete: {DefaultWorker, %{hey: "child you!"}, opts},
        on_success: {DefaultWorker, %{hey: "child me!"}, opts},
        parent_id: bid
      ]

      # child batch
      child_batch =
        Batch.build_payload(
          "tester",
          child_args
        )

      {:ok, child_bid} = Batch.new(child_batch, opts)
      # child batch job
      send_job_to_faktory(%{hey: "child batch job!", custom: %{bid: child_bid}}, opts)

      # commit child batch
      Batch.commit(child_bid, opts)
      # commit batch
      Batch.commit(bid, opts)

      {:ok, batch_status} = FaktoryTestHelpers.get_batch_status(bid)

      {:ok, child_batch_status} = FaktoryTestHelpers.get_batch_status(child_bid)

      assert child_batch_status["parent_bid"] == bid
      assert batch_status["bid"] == bid

      :ok = stop_supervised(faktory_name)
    end
  end

  defp send_job_to_faktory(job_args, opts) do
    job = Job.build_payload(DefaultWorker, job_args, opts)

    Job.perform_async(job, opts)
  end
end
