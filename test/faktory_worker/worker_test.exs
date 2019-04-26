defmodule FaktoryWorker.WorkerTest do
  use ExUnit.Case, async: true

  import Mox
  import FaktoryWorker.ConnectionHelpers
  import ExUnit.CaptureLog

  alias FaktoryWorker.Worker
  alias FaktoryWorker.Random
  alias FaktoryWorker.{DefaultWorker, TestQueueWorker, TimeoutQueueWorker}

  @fifteen_seconds 15_000

  setup :verify_on_exit!

  describe "new/2" do
    test "should return a worker struct" do
      worker_id = Random.worker_id()
      opts = [worker_id: worker_id, worker_module: TestQueueWorker]

      worker = Worker.new(opts)

      assert worker.worker_id == worker_id
      assert worker.worker_state == :ok
      assert worker.worker_module == TestQueueWorker
      assert worker.job_ref == nil
      assert worker.job_id == nil
      assert worker.job_timeout_ref == nil
      assert worker.beat_interval == @fifteen_seconds
    end

    test "should raise if no worker id is provided" do
      assert_raise KeyError, "key :worker_id not found in: []", fn ->
        Worker.new([])
      end
    end

    test "should raise if no worker module is provided" do
      opts = [worker_id: Random.worker_id()]

      assert_raise KeyError, "key :worker_module not found in: #{inspect(opts)}", fn ->
        Worker.new(opts)
      end
    end

    test "should open a new worker connection" do
      worker_connection_mox()

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker = Worker.new(opts)

      assert worker.conn != nil
    end

    test "should schedule a beat to be triggered" do
      opts = [worker_id: Random.worker_id(), worker_module: TestQueueWorker]

      worker = Worker.new(opts)

      assert is_reference(worker.beat_ref)
    end

    test "should schedule a fetch to be triggered" do
      opts = [worker_id: Random.worker_id(), worker_module: TestQueueWorker]

      Worker.new(opts)

      assert_received :fetch
    end
  end

  describe "send_beat/1" do
    test "should send a beat command and schedule next beat when state is ':ok'" do
      worker_id = Random.worker_id()
      beat_command = "BEAT {\"wid\":\"#{worker_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: worker_id,
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker = Worker.new(opts)

      result = Worker.send_beat(worker)

      assert is_reference(result.beat_ref)
      assert result.beat_ref != worker.beat_ref
    end

    test "should send a beat command and schedule next beat when state is ':quiet'" do
      worker_id = Random.worker_id()
      beat_command = "BEAT {\"wid\":\"#{worker_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: worker_id,
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker =
        opts
        |> Worker.new()
        |> Map.put(:worker_state, :quiet)

      result = Worker.send_beat(worker)

      assert is_reference(result.beat_ref)
      assert result.beat_ref != worker.beat_ref
    end

    test "should send a beat command and schedule next beat when state is ':running_job'" do
      worker_id = Random.worker_id()
      beat_command = "BEAT {\"wid\":\"#{worker_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: worker_id,
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker =
        opts
        |> Worker.new()
        |> Map.put(:worker_state, :running_job)

      result = Worker.send_beat(worker)

      assert is_reference(result.beat_ref)
      assert result.beat_ref != worker.beat_ref
    end

    test "should not send a beat command or schedule a next beat when state is ':terminate'" do
      worker_id = Random.worker_id()

      worker_connection_mox()

      opts = [
        worker_id: worker_id,
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Map.put(:worker_state, :terminate)
        |> Worker.send_beat()

      assert result.beat_ref == nil
    end

    test "should put worker into quiet state when receiving a quiet response from faktory" do
      worker_id = Random.worker_id()
      beat_command = "BEAT {\"wid\":\"#{worker_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+{\"state\":\"quiet\"}\r\n"}
      end)

      opts = [
        worker_id: worker_id,
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Worker.send_beat()

      assert result.worker_state == :quiet
    end

    test "should put worker into terminate state when receiving a terminate response from faktory" do
      worker_id = Random.worker_id()
      beat_command = "BEAT {\"wid\":\"#{worker_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+{\"state\":\"terminate\"}\r\n"}
      end)

      opts = [
        worker_id: worker_id,
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Worker.send_beat()

      assert result.worker_state == :terminate
    end

    test "should log when the beat state changes" do
      worker_id = Random.worker_id()
      beat_command = "BEAT {\"wid\":\"#{worker_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:error, :closed}
      end)

      # connection manager retries the command
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:error, :closed}
      end)

      opts = [
        worker_id: worker_id,
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker = Worker.new(opts)

      log_message =
        capture_log(fn ->
          Worker.send_beat(worker)
        end)

      assert log_message =~ "[faktory-worker] Heartbeat Failed"
    end
  end

  describe "send_end/1" do
    test "should send the 'END' command to faktory" do
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "END\r\n" ->
        :ok
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Worker.send_end()

      assert result.conn == nil
      assert result.worker_state == :ended
    end

    test "should not send 'END' command when no connection has been setup" do
      assert Worker.send_end(%{}) == %{}
    end
  end

  describe "send_fetch/1" do
    test "should send a fetch command and schedule next fetch when state is ':ok'" do
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH test_queue\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$-1\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> Worker.new()
      |> Worker.send_fetch()

      consume_initial_fetch_message()

      assert_received :fetch
    end

    test "should not send a fetch command and schedule next fetch when state is ':quiet'" do
      worker_connection_mox()

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> Worker.new()
      |> Map.put(:worker_state, :quiet)
      |> Worker.send_fetch()

      consume_initial_fetch_message()

      refute_received :fetch
    end

    test "should not send a fetch command and schedule next fetch when state is ':terminate'" do
      worker_connection_mox()

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> Worker.new()
      |> Map.put(:worker_state, :terminate)
      |> Worker.send_fetch()

      consume_initial_fetch_message()

      refute_received :fetch
    end

    test "should not send a fetch command and schedule next fetch when state is ':running_job'" do
      worker_connection_mox()

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> Worker.new()
      |> Map.put(:worker_state, :running_job)
      |> Worker.send_fetch()

      consume_initial_fetch_message()

      refute_received :fetch
    end

    test "should send a fetch command without a queue configured" do
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH default\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$-1\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: DefaultWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> Worker.new()
      |> Worker.send_fetch()
    end

    test "should leave the worker state set to ':ok' when there is no job to process" do
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH test_queue\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$-1\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Worker.send_fetch()

      assert result.worker_state == :ok
    end

    test "should log error, sleep, and schedule next fetch worker cannot connect" do
      expect(FaktoryWorker.SocketMock, :connect, fn _host, _port, _opts ->
        {:error, :econnrefused}
      end)

      expect(FaktoryWorker.SocketMock, :connect, fn _host, _port, _opts ->
        {:error, :econnrefused}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        retry_interval: 1,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker = Worker.new(opts)

      log_message = capture_log(fn -> Worker.send_fetch(worker) end)

      consume_initial_fetch_message()

      assert log_message =~
               "[faktory-worker] Failed to fetch job due to 'Failed to connect to Faktory' wid-#{
                 worker.worker_id
               }"

      assert_received :fetch
    end

    test "should log error, sleep, and then successfully fetch next time" do
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH test_queue\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "-SHUTDOWN Shutdown in progress\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        retry_interval: 1,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker = Worker.new(opts)

      log_message = capture_log(fn -> Worker.send_fetch(worker) end)

      consume_initial_fetch_message()

      assert log_message =~
               "[faktory-worker] Failed to fetch job due to 'Shutdown in progress' wid-#{
                 worker.worker_id
               }"

      assert_received :fetch
    end

    test "should set state to ':running_job' when there is a job to process" do
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      job =
        Jason.encode!(%{
          "args" => [%{"hey" => "there!"}],
          "created_at" => "2019-04-09T12:14:07.6550641Z",
          "enqueued_at" => "2019-04-09T12:14:07.6550883Z",
          "jid" => "f47ccc395ef9d9646118434f",
          "jobtype" => "FaktoryWorker.TestQueueWorker",
          "queue" => "test_queue"
        })

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH test_queue\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$#{byte_size(job)}\r\n"}
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _, _ ->
        {:ok, "#{job}\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Worker.send_fetch()

      assert result.worker_state == :running_job

      :ok = stop_supervised(FaktoryWorker_job_supervisor)
    end

    test "should run the job returned job in a new process" do
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      job =
        Jason.encode!(%{
          "args" => [%{"hey" => "there!", "_send_to_" => inspect(self())}],
          "created_at" => "2019-04-09T12:14:07.6550641Z",
          "enqueued_at" => "2019-04-09T12:14:07.6550883Z",
          "jid" => "f47ccc395ef9d9646118434f",
          "jobtype" => "FaktoryWorker.TestQueueWorker",
          "queue" => "test_queue"
        })

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH test_queue\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$#{byte_size(job)}\r\n"}
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _, _ ->
        {:ok, "#{job}\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Worker.send_fetch()

      assert %Task{} = result.job_ref
      assert result.job_id == "f47ccc395ef9d9646118434f"
      assert result.job_args == [%{"_send_to_" => "#{inspect(self())}", "hey" => "there!"}]
      assert is_reference(result.job_timeout_ref)

      assert_receive {TestQueueWorker, :perform, %{"hey" => "there!"}}, 50

      :ok = stop_supervised(FaktoryWorker_job_supervisor)
    end
  end

  describe "stop_job/1" do
    defp new_worker_with_job(opts) do
      job_ref =
        Task.Supervisor.async_nolink(
          FaktoryWorker_job_supervisor,
          fn -> Process.sleep(10_000) end,
          shutdown: :brutal_kill
        )

      opts
      |> Worker.new()
      |> Map.put(:job_ref, job_ref)
      |> Map.put(:job_id, "f47ccc395ef9d9646118434f")
      |> Map.put(:job_timeout_ref, :erlang.make_ref())
    end

    test "should stop the job process" do
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, _ ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TimeoutQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker = new_worker_with_job(opts)
      Worker.stop_job(worker)

      refute Process.alive?(worker.job_ref.pid)

      :ok = stop_supervised(FaktoryWorker_job_supervisor)
    end

    test "should send the 'FAIL' command" do
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      fail_payload =
        Jason.encode!(%{
          backtrace: [],
          errtype: "Undetected Error Type",
          jid: "f47ccc395ef9d9646118434f",
          message: "\"Job Timeout\""
        })

      fail_command = "FAIL #{fail_payload}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^fail_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TimeoutQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> new_worker_with_job()
      |> Worker.stop_job()

      :ok = stop_supervised(FaktoryWorker_job_supervisor)
    end

    test "should return the updated worker state" do
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, _ ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TimeoutQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      state =
        opts
        |> new_worker_with_job()
        |> Worker.stop_job()

      assert state.job_id == nil
      assert state.job_ref == nil
      assert state.job_timeout_ref == nil

      :ok = stop_supervised(FaktoryWorker_job_supervisor)
    end

    test "should handle the job already having completed" do
      worker_connection_mox()

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TimeoutQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker = Worker.new(opts)
      new_state = Worker.stop_job(worker)

      assert worker == new_state
    end

    test "should cancel the job timeout timer" do
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, _ ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TimeoutQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      timer_ref = Process.send_after(self(), :test_message, 5000)

      worker =
        opts
        |> new_worker_with_job()
        |> Map.put(:job_timeout_ref, timer_ref)
        |> Worker.stop_job()

      assert worker.job_timeout_ref == nil
      assert Process.cancel_timer(timer_ref) == false

      :ok = stop_supervised(FaktoryWorker_job_supervisor)
    end
  end

  describe "ack_job/2" do
    defp new_running_worker(opts, job_id) do
      opts
      |> Worker.new()
      |> Map.put(:job_id, job_id)
      |> Map.put(:job_ref, :erlang.make_ref())
      |> Map.put(:worker_state, :running_job)
    end

    test "should send a successful 'ACK' to faktory" do
      job_id = Random.string()
      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> new_running_worker(job_id)
        |> Worker.ack_job(:ok)

      assert result.worker_state == :ok
      assert result.job_ref == nil
      assert result.job_id == nil
      assert result.job_timeout_ref == nil
    end

    test "should log that a successful 'ACK' was sent to faktory" do
      job_id = Random.string()
      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      log_message =
        capture_log(fn ->
          opts
          |> new_running_worker(job_id)
          |> Worker.ack_job(:ok)
        end)

      assert log_message =~ "Succeeded jid-#{job_id}"
    end

    test "should schedule the next fetch for a successful ack" do
      job_id = Random.string()
      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> new_running_worker(job_id)
      |> Worker.ack_job(:ok)

      assert_received :fetch
    end

    test "should send a 'FAIL' to faktory for an unsuccessful job" do
      job_id = Random.string()

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

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      error = {%RuntimeError{message: "It went bang!"}, stacktrace}

      result =
        opts
        |> new_running_worker(job_id)
        |> Worker.ack_job({:error, error})

      assert result.worker_state == :ok
      assert result.job_ref == nil
      assert result.job_id == nil
      assert result.job_timeout_ref == nil
    end

    test "should log that a 'FAIL' was sent to faktory" do
      job_id = Random.string()

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

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      error = {%RuntimeError{message: "It went bang!"}, stacktrace}

      log_message =
        capture_log(fn ->
          opts
          |> new_running_worker(job_id)
          |> Worker.ack_job({:error, error})
        end)

      assert log_message =~ "Failed jid-#{job_id}"
    end

    test "should schedule the next fetch for an unsuccessful ack" do
      job_id = Random.string()

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

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      error = {%RuntimeError{message: "It went bang!"}, stacktrace}

      opts
      |> new_running_worker(job_id)
      |> Worker.ack_job({:error, error})

      assert_received :fetch
    end

    test "should log when there was an error sending the ack" do
      job_id = Random.string()
      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:error, :closed}
      end)

      # the connection manager retries a failed request once
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:error, :closed}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      log_message =
        capture_log(fn ->
          opts
          |> new_running_worker(job_id)
          |> Worker.ack_job(:ok)
        end)

      consume_initial_fetch_message()

      assert log_message =~
               "Error sending 'ACK' acknowledgement to faktory"

      assert_received :fetch
    end

    test "should log when there was an error sending the fail" do
      job_id = Random.string()

      fail_payload = %{
        jid: job_id,
        errtype: "Undetected Error Type",
        message: "exit",
        backtrace: []
      }

      fail_command = "FAIL #{Jason.encode!(fail_payload)}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^fail_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:error, :closed}
      end)

      # the connection manager retries a failed request one more time
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^fail_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:error, :closed}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      log_message =
        capture_log(fn ->
          opts
          |> new_running_worker(job_id)
          |> Worker.ack_job({:error, :exit})
        end)

      consume_initial_fetch_message()

      assert log_message =~
               "Error sending 'FAIL' acknowledgement to faktory"

      assert_received :fetch
    end

    test "should cancel the job timeout when acknowledging a successful job" do
      job_id = Random.string()
      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      timer_ref = Process.send_after(self(), :test_message, 5000)

      result =
        opts
        |> new_running_worker(job_id)
        |> Map.put(:job_timeout_ref, timer_ref)
        |> Worker.ack_job(:ok)

      assert result.job_timeout_ref == nil
      assert Process.cancel_timer(timer_ref) == false
    end

    test "should cancel the job timeout when acknowledging a failed job" do
      job_id = Random.string()

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

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      error = {%RuntimeError{message: "It went bang!"}, stacktrace}
      timer_ref = Process.send_after(self(), :test_message, 5000)

      result =
        opts
        |> new_running_worker(job_id)
        |> Map.put(:job_timeout_ref, timer_ref)
        |> Worker.ack_job({:error, error})

      assert result.job_timeout_ref == nil
      assert Process.cancel_timer(timer_ref) == false
    end
  end

  defp consume_initial_fetch_message() do
    # calling Worker.new/1 schedules an initial fetch
    receive do
      :fetch -> :ok
    after
      1 -> :error
    end
  end
end
