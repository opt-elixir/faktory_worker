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
        worker_pool: [size: 10, queues: ["test1", {"test2", max_concurrency: 5}, "test3"]]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      {_concurrency_per_worker, queues} = :sys.get_state(pid)

      assert queues == [
               %QueueManager.Queue{name: "test1", max_concurrency: 10},
               %QueueManager.Queue{name: "test2", max_concurrency: 5},
               %QueueManager.Queue{name: "test3", max_concurrency: 10}
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
        worker_pool: [
          size: 10,
          queues: ["test1", {"test2", max_concurrency: 5}, {"test3", max_concurrency: 11}]
        ]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      queues = QueueManager.checkout_queues(pid)

      assert queues == ["test3", "test1", "test2"]
    end

    test "should update the max concurrency state when checking out a queue" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [size: 10, queues: ["test1", {"test2", max_concurrency: 5}]]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      queues = QueueManager.checkout_queues(pid)
      {_concurrency_per_worker, state} = :sys.get_state(pid)

      assert queues == ["test1", "test2"]

      assert state == [
               %QueueManager.Queue{name: "test1", max_concurrency: 9},
               %QueueManager.Queue{name: "test2", max_concurrency: 4}
             ]
    end

    test "should not return a queue when the max concurrency reaches 0" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [
          size: 10,
          queues: [{"test1", max_concurrency: 1}, {"test2", max_concurrency: 2}]
        ]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      queues_result1 = QueueManager.checkout_queues(pid)
      queues_result2 = QueueManager.checkout_queues(pid)
      queues_result3 = QueueManager.checkout_queues(pid)

      {_concurrency_per_worker, state} = :sys.get_state(pid)

      assert queues_result1 == ["test2"]
      assert queues_result2 == ["test1"]
      assert queues_result3 == ["test2"]

      assert state == [
               %QueueManager.Queue{name: "test1", max_concurrency: 0},
               %QueueManager.Queue{name: "test2", max_concurrency: 0}
             ]
    end
  end

  describe "checkin_queues/2" do
    test "it should update the queues max concurrency counts when checking in a queue with a max concurrency set" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [size: 10, queues: ["test1", {"test2", max_concurrency: 1}]]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      :ok = QueueManager.checkin_queues(pid, ["test1", "test2"])

      {_concurrency_per_worker, state} = :sys.get_state(pid)

      assert state == [
               %QueueManager.Queue{name: "test1", max_concurrency: 11},
               %QueueManager.Queue{name: "test2", max_concurrency: 2}
             ]
    end

    test "it should not update the max concurrency value when the queue is not checked in" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [size: 10, queues: ["test1", {"test2", max_concurrency: 1}]]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      :ok = QueueManager.checkin_queues(pid, ["test1"])

      {_concurrency_per_worker, state} = :sys.get_state(pid)

      assert state == [
               %QueueManager.Queue{name: "test1", max_concurrency: 11},
               %QueueManager.Queue{name: "test2", max_concurrency: 1}
             ]
    end
  end

  describe "queue distribution" do
    test "it should distribute queues evenly in limited concurrency" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [
          size: 3,
          queues: [
            {"A", max_concurrency: 2},
            {"B", max_concurrency: 3},
            {"C", max_concurrency: 1},
            {"D", max_concurrency: 3}
          ]
        ]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      queues_result1 = pid |> QueueManager.checkout_queues() |> Enum.sort()
      queues_result2 = pid |> QueueManager.checkout_queues() |> Enum.sort()
      queues_result3 = pid |> QueueManager.checkout_queues() |> Enum.sort()
      queues_result4 = pid |> QueueManager.checkout_queues() |> Enum.sort()

      assert queues_result1 == ["A", "B", "D"]
      assert queues_result2 == ["B", "C", "D"]
      assert queues_result3 == ["A", "B", "D"]
      assert queues_result4 == []

      :ok = QueueManager.checkin_queues(pid, queues_result1)

      queues_result5 = pid |> QueueManager.checkout_queues() |> Enum.sort()

      assert queues_result1 == queues_result5
    end

    test "every worker will get every queue in infinite concurrency" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [
          size: 3,
          queues: [
            "A",
            "B",
            "C",
            "D"
          ]
        ]
      ]

      {:ok, pid} = QueueManager.start_link(opts)

      queues_result1 = pid |> QueueManager.checkout_queues() |> Enum.sort()
      queues_result2 = pid |> QueueManager.checkout_queues() |> Enum.sort()
      queues_result3 = pid |> QueueManager.checkout_queues() |> Enum.sort()
      queues_result4 = pid |> QueueManager.checkout_queues() |> Enum.sort()

      assert queues_result1 == ["A", "B", "C", "D"]
      assert queues_result2 == ["A", "B", "C", "D"]
      assert queues_result3 == ["A", "B", "C", "D"]
      assert queues_result4 == []

      :ok = QueueManager.checkin_queues(pid, queues_result1)

      queues_result5 = pid |> QueueManager.checkout_queues() |> Enum.sort()

      assert queues_result1 == queues_result5
    end
  end
end
