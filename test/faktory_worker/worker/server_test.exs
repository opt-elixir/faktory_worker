defmodule FaktoryWorker.Worker.ServerTest do
  # we are using 'set_mox_global' so we cannot run async tests
  use ExUnit.Case, async: false

  import Mox
  import FaktoryWorker.ConnectionHelpers

  alias FaktoryWorker.Worker.Server
  alias FaktoryWorker.Random
  alias FaktoryWorker.{TestQueueWorker, TimeoutQueueWorker}

  setup :set_mox_global
  setup :verify_on_exit!

  describe "child_spec/1" do
    test "should return a default child_spec" do
      opts = [name: :test_worker_1]
      child_spec = Server.child_spec(opts)

      assert child_spec == %{
               id: :test_worker_1,
               start: {FaktoryWorker.Worker.Server, :start_link, [[name: :test_worker_1]]},
               type: :worker
             }
    end

    test "should allow connection config to be specified" do
      opts = [name: :test_worker_1, connection: [port: 7000]]
      child_spec = Server.child_spec(opts)

      assert child_spec == %{
               id: :test_worker_1,
               start:
                 {FaktoryWorker.Worker.Server, :start_link,
                  [[name: :test_worker_1, connection: [port: 7000]]]},
               type: :worker
             }
    end
  end

  describe "start_link/1" do
    test "should start the worker server" do
      opts = [name: :test_worker_1, worker_id: Random.worker_id(), worker_module: TestQueueWorker]
      pid = start_supervised!(Server.child_spec(opts))

      assert pid == Process.whereis(:test_worker_1)

      :ok = stop_supervised(:test_worker_1)
    end

    test "should open a connection to faktory" do
      worker_connection_mox()
      connection_close_mox()

      opts = [
        name: :test_worker_1,
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      pid = start_supervised!(Server.child_spec(opts))

      %{conn_pid: conn_pid} = :sys.get_state(pid)

      state = :sys.get_state(conn_pid)

      assert state.conn.host == "localhost"
      assert state.conn.port == 7419
      assert state.conn.socket_handler == FaktoryWorker.SocketMock
      assert state.conn.socket == :test_socket

      :ok = stop_supervised(:test_worker_1)
    end
  end

  describe "handle_info/2" do
    test "should handle the connection process exiting and stop the worker" do
      worker_connection_mox()

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      pid = start_supervised!(Server.child_spec(opts))
      state = :sys.get_state(pid)

      {:stop, :normal, state} = Server.handle_info({:EXIT, state.conn_pid, :shutdown}, state)

      assert state.conn_pid == nil
    end
  end

  describe "termiante/2" do
    test "should send the 'END' command when the server terminates" do
      worker_connection_mox()
      connection_close_mox()

      opts = [
        name: :test_worker_1,
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      _ = start_supervised!(Server.child_spec(opts))

      # shuts down the process, see connection_close_mox for test expectations
      :ok = stop_supervised(:test_worker_1)
    end
  end

  describe "job timeout" do
    test "should ignore a job timeout when the job completed before the timeout message is handled" do
      worker_connection_mox()
      connection_close_mox()

      opts = [
        name: :test_worker_1,
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      pid = start_supervised!(Server.child_spec(opts))
      monitor_ref = Process.monitor(pid)

      # let the server fully boot up
      %{worker_state: :ok} = :sys.get_state(pid)

      Process.send(pid, :job_timeout, [])

      refute_receive {:DOWN, ^monitor_ref, :process, ^pid, _}, 20

      :ok = stop_supervised(:test_worker_1)
    end
  end

  describe "worker lifecycle" do
    test "should issue regular 'BEAT' commands" do
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "BEAT " <> _ ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      expect(FaktoryWorker.SocketMock, :send, fn _, "BEAT " <> _ ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        # return the terminate state here to prevent futher beat commands
        {:ok, "+{\"state\": \"terminate\"}\r\n"}
      end)

      connection_close_mox()

      opts = [
        name: :test_worker_1,
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        beat_interval: 1,
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      pid = start_supervised!(Server.child_spec(opts))

      %{worker_state: :ok} = :sys.get_state(pid)

      # sleep 5 milliseconds to allow both beats to occur
      Process.sleep(5)

      :ok = stop_supervised(:test_worker_1)
    end

    test "should send 'ACK' command when a job completes successfully" do
      job_id = "f47ccc395ef9d9646118434f"
      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      connection_close_mox()

      opts = [
        name: :test_worker_1,
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      pid = start_supervised!(Server.child_spec(opts))

      :sys.replace_state(pid, fn state ->
        Map.put(state, :job_id, job_id)
      end)

      Process.send(pid, {:erlang.make_ref(), :ok}, [])

      :ok = stop_supervised(:test_worker_1)
    end

    test "should send 'FAIL' command when a job fails to complete" do
      job_id = "f47ccc395ef9d9646118434f"

      {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)

      fail_payload = %{
        jid: job_id,
        errtype: "Elixir.RuntimeError",
        message: "It went bang!",
        backtrace: Enum.map(stacktrace, &Exception.format_stacktrace_entry/1)
      }

      fail_command = "FAIL #{Jason.encode!(fail_payload)}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^fail_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      connection_close_mox()

      opts = [
        name: :test_worker_1,
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      pid = start_supervised!(Server.child_spec(opts))

      :sys.replace_state(pid, fn state ->
        Map.put(state, :job_id, job_id)
      end)

      reason = {%RuntimeError{message: "It went bang!"}, stacktrace}

      Process.send(pid, {:DOWN, :erlang.make_ref(), :process, self(), reason}, [])

      :ok = stop_supervised(:test_worker_1)
    end

    test "should send 'FAIL' command when a job times out" do
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      job =
        Jason.encode!(%{
          "args" => [%{"hey" => "there!"}],
          "created_at" => "2019-04-09T12:14:07.6550641Z",
          "enqueued_at" => "2019-04-09T12:14:07.6550883Z",
          "jid" => "f47ccc395ef9d9646118434f",
          "jobtype" => "FaktoryWorker.TestQueueWorker",
          "reserve_for" => 20,
          "queue" => "timeout_queue"
        })

      fail_payload =
        Jason.encode!(%{
          backtrace: [],
          errtype: "Undetected Error Type",
          jid: "f47ccc395ef9d9646118434f",
          message: "\"Job Timeout\""
        })

      fail_command = "FAIL #{fail_payload}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH timeout_queue\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$#{byte_size(job)}\r\n"}
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _, _ ->
        {:ok, "#{job}\r\n"}
      end)

      expect(FaktoryWorker.SocketMock, :send, fn _, ^fail_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      connection_close_mox()

      opts = [
        name: :test_worker_1,
        worker_id: Random.worker_id(),
        worker_module: TimeoutQueueWorker,
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      pid = start_supervised!(Server.child_spec(opts))

      Process.send(pid, :fetch, [])

      Process.sleep(1000)

      :ok = stop_supervised(:test_worker_1)
      :ok = stop_supervised(FaktoryWorker_job_supervisor)
    end
  end
end
