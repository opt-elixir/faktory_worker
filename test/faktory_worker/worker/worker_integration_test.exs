defmodule FaktoryWorker.WorkerIntegrationTest do
  use ExUnit.Case

  alias FaktoryWorker.Worker

  describe "start_link/1" do
    test "should start the worker and connect to faktory" do
      opts = [name: :test_worker_1]
      pid = start_supervised!(Worker.child_spec(opts))

      %{conn: connection_manager} = :sys.get_state(pid)

      assert connection_manager.conn.host == "localhost"
      assert connection_manager.conn.port == 7419
      assert connection_manager.conn.socket_handler == FaktoryWorker.Socket.Tcp
      assert is_port(connection_manager.conn.socket)

      :ok = stop_supervised(:test_worker_1)
    end
  end
end
