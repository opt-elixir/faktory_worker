defmodule FaktoryWorker.Worker.PoolTest do
  use ExUnit.Case

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
      opts = [name: FaktoryWorker]

      {:ok, pid} = Pool.start_link(opts)

      assert pid == Process.whereis(FaktoryWorker_worker_pool)

      :ok = Supervisor.stop(pid)
    end

    test "should start the list of specified workers" do
      opts = [name: FaktoryWorker, workers: [SingleWorker]]
      {:ok, pid} = Pool.start_link(opts)

      [{worker_name, _, type, [server_module]}] = Supervisor.which_children(pid)
      [worker_name, worker_id] = split_worker_name(worker_name)

      assert worker_name == "SingleWorker"
      assert byte_size(worker_id) == 16
      assert type == :worker
      assert server_module == FaktoryWorker.Worker.Server

      :ok = Supervisor.stop(pid)
    end

    test "should start the list of specified workers with concurrency settings" do
      opts = [name: FaktoryWorker, workers: [SingleWorker, MultiWorker]]
      {:ok, pid} = Pool.start_link(opts)
      children = Supervisor.which_children(pid)

      %{"SingleWorker" => single_workers, "MultiWorker" => multi_workers} =
        children
        |> Enum.group_by(
          fn {worker_name, _, _, _} ->
            worker_name
            |> split_worker_name()
            |> List.first()
          end,
          fn {worker_name, _, _, _} ->
            worker_name
            |> split_worker_name()
            |> List.last()
          end
        )

      assert length(children) == 11
      assert length(single_workers) == 1
      assert length(multi_workers) == 10

      :ok = Supervisor.stop(pid)
    end
  end

  describe "format_worker_pool_name/1" do
    test "should return the pool name" do
      name = Pool.format_worker_pool_name(name: :test)
      assert name == :test_worker_pool
    end
  end

  defp split_worker_name(worker_name) do
    [_, _, _, worker_name] = Module.split(worker_name)
    String.split(worker_name, "_")
  end
end
