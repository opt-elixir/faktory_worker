defmodule FaktoryWorker.Worker.PoolTest do
  use ExUnit.Case

  alias FaktoryWorker.Random
  alias FaktoryWorker.Worker.Pool

  defmodule SingleWorker do
    use FaktoryWorker.Job,
      disable_fetch: true

    def perform(_), do: :ok
  end

  defmodule MultiWorker do
    use FaktoryWorker.Job,
      disable_fetch: true,
      concurrency: 10

    def perform(_), do: :ok
  end

  describe "start_link/1" do
    test "should start the supervisor" do
      opts = [
        name: FaktoryWorker,
        process_wid: Random.process_wid(),
        worker_pool: [disable_fetch: true]
      ]

      {:ok, pid} = start_supervised({Pool, opts})

      assert pid == Process.whereis(FaktoryWorker_worker_pool)

      :ok = stop_supervised(Pool)
    end

    test "should start the list of specified workers" do
      process_wid = Random.process_wid()

      opts = [
        name: FaktoryWorker,
        worker_pool: [size: 1, queues: ["test_queue"], disable_fetch: true],
        process_wid: process_wid
      ]

      {:ok, pid} = start_supervised({Pool, opts})

      [{worker_name, _, type, [server_module]} | _] = Supervisor.which_children(pid)
      [_, found_process_wid, number] = split_worker_name(worker_name)

      assert number == "1"
      assert process_wid == found_process_wid
      assert type == :worker
      assert server_module == FaktoryWorker.Worker.Server

      :ok = stop_supervised(Pool)
    end

    test "should start 10 connections by default" do
      opts = [
        name: FaktoryWorker,
        worker_pool: [queues: ["test_queue"], disable_fetch: true],
        process_wid: Random.process_wid()
      ]

      {:ok, pid} = start_supervised({Pool, opts})

      assert Supervisor.count_children(pid).workers == 10

      :ok = stop_supervised(Pool)
    end
  end

  describe "format_worker_pool_name/1" do
    test "should return the pool name" do
      name = Pool.format_worker_pool_name(name: :test)
      assert name == :test_worker_pool
    end
  end

  defp split_worker_name(worker_name) do
    worker_name
    |> Atom.to_string()
    |> String.split("_")
  end
end
