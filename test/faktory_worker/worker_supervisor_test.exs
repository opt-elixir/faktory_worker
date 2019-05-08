defmodule FaktoryWorker.WorkerSupervisorTest do
  use ExUnit.Case

  alias FaktoryWorker.WorkerSupervisor

  describe "start_link/1" do
    test "should start the supervisor" do
      opts = [name: FaktoryWorker]

      {:ok, pid} = WorkerSupervisor.start_link(opts)

      assert pid == Process.whereis(FaktoryWorker_worker_supervisor)

      :ok = Supervisor.stop(pid)
    end

    test "should start children" do
      opts = [name: FaktoryWorker]

      {:ok, pid} = WorkerSupervisor.start_link(opts)

      children = Supervisor.which_children(pid)

      [shutdown_manager, heartbeat_server, pool] = children

      assert {FaktoryWorker_shutdown_manager, _, :worker, [FaktoryWorker.Worker.ShutdownManager]} =
               shutdown_manager

      assert {FaktoryWorker_heartbeat_server, _, :worker, [FaktoryWorker.Worker.HeartbeatServer]} =
               heartbeat_server

      assert {FaktoryWorker.Worker.Pool, _, :supervisor, [FaktoryWorker.Worker.Pool]} = pool

      :ok = Supervisor.stop(pid)
    end
  end
end
