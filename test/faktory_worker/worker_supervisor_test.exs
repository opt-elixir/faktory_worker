defmodule FaktoryWorker.WorkerSupervisorTest do
  use ExUnit.Case

  alias FaktoryWorker.WorkerSupervisor

  defmodule SingleWorker do
    use FaktoryWorker.Job
  end

  defmodule MultiWorker do
    use FaktoryWorker.Job,
      concurrency: 10
  end

  describe "start_link/1" do
    test "should start the supervisor" do
      opts = [name: FaktoryWorker]

      {:ok, pid} = WorkerSupervisor.start_link(opts)

      assert pid == Process.whereis(FaktoryWorker_worker_supervisor)

      :ok = Supervisor.stop(pid)
    end

    test "should start the list of specified workers" do
      opts = [name: FaktoryWorker, workers: [SingleWorker]]
      {:ok, pid} = WorkerSupervisor.start_link(opts)

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
      {:ok, pid} = WorkerSupervisor.start_link(opts)

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

  defp split_worker_name(worker_name) do
    [_, _, worker_name] = Module.split(worker_name)
    String.split(worker_name, "_")
  end
end
