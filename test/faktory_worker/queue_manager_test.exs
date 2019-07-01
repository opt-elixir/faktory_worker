defmodule FaktoryWorker.QueueManagerTest do
  use ExUnit.Case

  alias FaktoryWorker.QueueManager

  describe "start_link/1" do
    test "should start the queue manager" do
      opts = [name: FaktoryWorker]

      {:ok, pid} = QueueManager.start_link(opts)

      assert pid == Process.whereis(FaktoryWorker_queue_manager)

      :ok = Supervisor.stop(pid)
    end

    test "should set the queues state" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [queues: ["test1", {"test2", max_concurrency: 5}, "test3"]]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      state = :sys.get_state(pid)

      assert state == [
               %QueueManager.Queue{name: "test1", max_concurrency: :infinity},
               %QueueManager.Queue{name: "test2", max_concurrency: 5},
               %QueueManager.Queue{name: "test3", max_concurrency: :infinity}
             ]
    end
  end

  describe "format_queue_manager_name/1" do
    test "should return the given name with the queue manager suffix" do
      assert :test_queue_manager == QueueManager.format_queue_manager_name(:test)
    end
  end

  describe "checkout_queues/1" do
    test "should return a list of queues eligible to fetch on" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [queues: ["test1", {"test2", max_concurrency: 5}, "test3"]]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      queues = QueueManager.checkout_queues(pid)

      assert queues == ["test1", "test2", "test3"]
    end

    test "should update the max concurrency state when checking out a queue" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [queues: ["test1", {"test2", max_concurrency: 5}]]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      queues = QueueManager.checkout_queues(pid)
      state = :sys.get_state(pid)

      assert queues == ["test1", "test2"]

      assert state == [
               %QueueManager.Queue{name: "test1", max_concurrency: :infinity},
               %QueueManager.Queue{name: "test2", max_concurrency: 4}
             ]
    end

    test "should not return a queue when the max concurrency reaches 0" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [queues: ["test1", {"test2", max_concurrency: 1}]]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      queues_result1 = QueueManager.checkout_queues(pid)
      queues_result2 = QueueManager.checkout_queues(pid)

      state = :sys.get_state(pid)

      assert queues_result1 == ["test1", "test2"]
      assert queues_result2 == ["test1"]

      assert state == [
               %QueueManager.Queue{name: "test1", max_concurrency: :infinity},
               %QueueManager.Queue{name: "test2", max_concurrency: 0}
             ]
    end
  end

  describe "checkin_queues/2" do
    test "it should update the queues max concurrency counts when checking in a queue with a max concurrency set" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [queues: ["test1", {"test2", max_concurrency: 1}]]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      :ok = QueueManager.checkin_queues(pid, ["test1", "test2"])

      state = :sys.get_state(pid)

      assert state == [
               %QueueManager.Queue{name: "test1", max_concurrency: :infinity},
               %QueueManager.Queue{name: "test2", max_concurrency: 2}
             ]
    end

    test "it should not update the max concurrency value when the queue is not checked in" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [queues: ["test1", {"test2", max_concurrency: 1}]]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      :ok = QueueManager.checkin_queues(pid, ["test1"])

      state = :sys.get_state(pid)

      assert state == [
               %QueueManager.Queue{name: "test1", max_concurrency: :infinity},
               %QueueManager.Queue{name: "test2", max_concurrency: 1}
             ]
    end
  end
end
