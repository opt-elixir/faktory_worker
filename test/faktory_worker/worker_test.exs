defmodule FaktoryWorker.WorkerTest do
  use ExUnit.Case, async: true

  import Mox
  import FaktoryWorker.ConnectionHelpers

  alias FaktoryWorker.Worker
  alias FaktoryWorker.Random
  alias FaktoryWorker.{DefaultWorker, TestQueueWorker}

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
  end

  describe "send_end/1" do
    test "should send the 'END' command to faktory" do
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "END\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      expect(FaktoryWorker.SocketMock, :close, fn _ ->
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

      assert_receive {TestQueueWorker, :perform, %{"hey" => "there!"}}, 50

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
