defmodule FaktoryWorker.Worker.ServerIntegrationTest do
  use ExUnit.Case, async: false

  import FaktoryWorker.FaktoryTestHelpers

  alias FaktoryWorker.Worker.Server
  alias FaktoryWorker.Random
  alias FaktoryWorker.TestQueueWorker

  setup :flush_faktory!

  describe "start_link/1" do
    test "should start the worker server and connect to faktory" do
      opts = [
        name: :test_worker_1,
        process_wid: Random.process_wid(),
        queues: ["test_queue"],
        disable_fetch: true
      ]

      pid = start_supervised!(Server.child_spec(opts))

      %{conn_pid: conn_pid} = :sys.get_state(pid)

      state = :sys.get_state(conn_pid)

      assert state.conn.host == "localhost"
      assert state.conn.port == 7419
      assert state.conn.socket_handler == FaktoryWorker.Socket.Tcp
      assert is_port(state.conn.socket)

      :ok = stop_supervised(:test_worker_1)
    end
  end

  describe "worker lifecyle" do
    test "should send multiple 'FETCH' commands" do
      start_supervised!(
        FaktoryWorker.child_spec(pool: [size: 1], worker_pool: [size: 1, queues: ["test_queue"]])
      )

      job1 = %{"job" => "one", "_send_to_" => inspect(self())}
      job2 = %{"job" => "two", "_send_to_" => inspect(self())}

      TestQueueWorker.perform_async(job1)
      TestQueueWorker.perform_async(job2)

      assert_receive {TestQueueWorker, :perform, %{"job" => "one"}}
      assert_receive {TestQueueWorker, :perform, %{"job" => "two"}}

      :ok = stop_supervised(FaktoryWorker)
    end
  end
end
