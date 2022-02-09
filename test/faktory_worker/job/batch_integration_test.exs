defmodule FaktoryWorker.BatchIntegrationTest do
  use ExUnit.Case
  @moduletag :enterprise

  import FaktoryWorker.FaktoryTestHelpers

  alias FaktoryWorker.{Random, DefaultWorker, Batch}

  setup :flush_faktory!

  setup do
    faktory_name = :"Test_#{Random.string()}"

    faktory_opts = [
      name: faktory_name,
      pool: [size: 1],
      worker_pool: [disable_fetch: true]
    ]

    start_supervised!({FaktoryWorker, faktory_opts})

    {:ok, faktory_name: faktory_name}
  end

  describe "new!/1" do
    test "creates a new batch", %{faktory_name: faktory_name} do
      opts = [
        description: "Test batch",
        on_complete: {DefaultWorker, ["complete"], []},
        faktory_name: faktory_name
      ]

      {:ok, bid} = Batch.new!(opts)

      job_opts = [
        faktory_name: faktory_name,
        custom: %{"bid" => bid}
      ]

      DefaultWorker.perform_async(["1"], job_opts)
      DefaultWorker.perform_async(["2"], job_opts)

      Batch.commit(bid, opts)

      {:ok, status} = Batch.status(bid, faktory_name: faktory_name)

      assert status["pending"] == 2
      assert status["total"] == 2
    end

    test "raises if no callbacks are defined", %{faktory_name: faktory_name} do
      opts = [faktory_name: faktory_name]

      message = "Faktory batch jobs must declare a success or complete callback"

      assert_raise RuntimeError, message, fn ->
        Batch.new!(opts)
      end
    end
  end

  describe "open/2" do
    test "allows opening a batch and adding new jobs", %{faktory_name: faktory_name} do
      opts = [
        description: "Test batch",
        on_complete: {DefaultWorker, ["complete"], []},
        faktory_name: faktory_name
      ]

      {:ok, bid} = Batch.new!(opts)

      job_opts = [
        faktory_name: faktory_name,
        custom: %{"bid" => bid}
      ]

      DefaultWorker.perform_async(["1"], job_opts)
      DefaultWorker.perform_async(["2"], job_opts)

      Batch.commit(bid, opts)

      Batch.open(bid, opts)

      DefaultWorker.perform_async(["3"], job_opts)
      DefaultWorker.perform_async(["4"], job_opts)

      Batch.commit(bid, opts)

      {:ok, status} = Batch.status(bid, faktory_name: faktory_name)

      assert status["pending"] == 4
      assert status["total"] == 4
    end
  end
end
