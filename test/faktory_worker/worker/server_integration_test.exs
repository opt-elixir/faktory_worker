defmodule FaktoryWorker.Worker.ServerIntegrationTest do
  use ExUnit.Case

  alias FaktoryWorker.Worker.Server
  alias FaktoryWorker.Random
  alias FaktoryWorker.TestQueueWorker

  describe "start_link/1" do
    test "should start the worker server and connect to faktory" do
      opts = [name: :test_worker_1, worker_id: Random.worker_id(), worker_module: TestQueueWorker]
      pid = start_supervised!(Server.child_spec(opts))

      %{conn: connection_manager} = :sys.get_state(pid)

      assert connection_manager.conn.host == "localhost"
      assert connection_manager.conn.port == 7419
      assert connection_manager.conn.socket_handler == FaktoryWorker.Socket.Tcp
      assert is_port(connection_manager.conn.socket)

      :ok = stop_supervised(:test_worker_1)
    end
  end
end
