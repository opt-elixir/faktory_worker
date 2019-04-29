defmodule FaktoryWorker.Worker.ShutdownServerTest do
  use ExUnit.Case

  alias FaktoryWorker.Worker.ShutdownManager

  describe "start_link2" do
    test "should start the supervisor" do
      opts = [name: FaktoryWorker]

      # need to start a pool to prevent error when
      # terminating the shutdown server
      start_supervised!({FaktoryWorker.Worker.Pool, opts})

      {:ok, pid} = ShutdownManager.start_link(opts)

      assert pid == Process.whereis(FaktoryWorker_shutdown_manager)

      :ok = Supervisor.stop(pid)
    end
  end
end
