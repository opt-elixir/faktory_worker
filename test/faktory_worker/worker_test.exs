defmodule FaktoryWorker.WorkerTest do
  use ExUnit.Case

  import Mox
  import FaktoryWorker.ConnectionHelpers
  import FaktoryWorker.EventHandlerTestHelpers

  alias FaktoryWorker.Worker
  alias FaktoryWorker.Random
  alias FaktoryWorker.QueueManager

  setup :set_mox_global
  setup :verify_on_exit!

  describe "new/2" do
    test "should return a worker struct" do
      process_wid = Random.process_wid()
      opts = [process_wid: process_wid]

      worker = Worker.new(opts)

      assert worker.process_wid == process_wid
      assert worker.worker_state == :ok
      assert worker.queues == nil
      assert worker.job_ref == nil
      assert worker.job_id == nil
      assert worker.job_timeout_ref == nil
    end

    test "should raise if no worker id is provided" do
      assert_raise KeyError, "key :process_wid not found in: []", fn ->
        Worker.new([])
      end
    end

    test "should open a new worker connection" do
      worker_connection_mox()

      opts = [
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker = Worker.new(opts)

      assert is_pid(worker.conn_pid)
    end

    test "should schedule a fetch to be triggered" do
      opts = [process_wid: Random.process_wid()]

      Worker.new(opts)

      assert_receive :fetch
    end
  end

  describe "send_fetch/1" do
    test "should send a fetch command and schedule next fetch when state is ':ok'" do
      worker_pool = [queues: ["test_queue"]]

      start_supervised!({QueueManager, name: FaktoryWorker, worker_pool: worker_pool})
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH test_queue\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$-1\r\n"}
      end)

      opts = [
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> Worker.new()
      |> Worker.send_fetch()

      consume_initial_fetch_message()

      assert_receive :fetch
    end

    test "should not send a fetch command and schedule next fetch when state is ':quiet'" do
      worker_connection_mox()

      opts = [
        process_wid: Random.process_wid(),
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
        process_wid: Random.process_wid(),
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
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> Worker.new()
      |> Map.put(:worker_state, :running_job)
      |> Worker.send_fetch()

      consume_initial_fetch_message()

      refute_received :fetch
    end

    test "should start the fetch command in a new process" do
      worker_pool = [queues: ["test_queue"]]

      start_supervised!({QueueManager, name: FaktoryWorker, worker_pool: worker_pool})
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
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Worker.send_fetch()

      assert %Task{} = result.fetch_ref

      assert_receive :fetch
    end

    test "should send a fetch command with multiple queues" do
      worker_pool = [queues: ["test_queue", "default"]]

      start_supervised!({QueueManager, name: FaktoryWorker, worker_pool: worker_pool})
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH test_queue default\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$-1\r\n"}
      end)

      opts = [
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> Worker.new()
      |> Worker.send_fetch()

      consume_initial_fetch_message()

      assert_receive :fetch
    end

    test "should maintain the queues between fetches that do not return a job" do
      worker_pool = [queues: ["test_queue", "default"]]

      start_supervised!({QueueManager, name: FaktoryWorker, worker_pool: worker_pool})
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH test_queue default\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$-1\r\n"}
      end)

      opts = [
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      state =
        opts
        |> Worker.new()
        |> Worker.send_fetch()

      consume_initial_fetch_message()

      state = Worker.send_fetch(state)

      assert state.queues == ["test_queue", "default"]
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
      |> Map.put(:job, %{"jid" => "f47ccc395ef9d9646118434f"})
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
        process_wid: Random.process_wid(),
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
        process_wid: Random.process_wid(),
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
        process_wid: Random.process_wid(),
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
        process_wid: Random.process_wid(),
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
        process_wid: Random.process_wid(),
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

  describe "handle_fetch_response/2" do
    test "should run the job in a process" do
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      job = %{
        "args" => [%{"hey" => "there!"}],
        "created_at" => "2019-04-09T12:14:07.6550641Z",
        "enqueued_at" => "2019-04-09T12:14:07.6550883Z",
        "jid" => "f47ccc395ef9d9646118434f",
        "jobtype" => "FaktoryWorker.TestQueueWorker",
        "queue" => "test_queue"
      }

      state = %{
        faktory_name: FaktoryWorker,
        worker_state: :ok,
        job_timeout_ref: nil,
        job_ref: nil,
        job_id: nil,
        job: nil
      }

      new_state = Worker.handle_fetch_response({:ok, job}, state)

      assert new_state.worker_state == :running_job
      assert Process.alive?(new_state.job_ref.pid)
    end

    test "should ignore an empty fetch response and schedule fetch" do
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      state = %{
        faktory_name: FaktoryWorker,
        worker_state: :ok,
        job_timeout_ref: nil,
        job_ref: nil,
        job_id: nil,
        job: nil
      }

      Worker.handle_fetch_response({:ok, :no_content}, state)

      assert_receive :fetch
    end

    test "should execute event, sleep, and then successfully fetch next time" do
      event_handler_id = attach_event_handler([:fetch])

      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      worker_connection_mox()

      opts = [
        process_wid: Random.process_wid(),
        retry_interval: 1,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      state = Worker.new(opts)

      consume_initial_fetch_message()

      Worker.handle_fetch_response({:error, "Shutdown in progress"}, state)

      assert_receive {[:faktory_worker, :fetch], outcome, metadata}
      assert outcome == %{status: {:error, "Shutdown in progress"}}

      assert metadata == %{
               wid: state.process_wid
             }

      assert_receive :fetch

      detach_event_handler(event_handler_id)
    end

    test "should execute event and schedule next fetch when worker cannot connect" do
      event_handler_id = attach_event_handler([:fetch])
      start_supervised!({FaktoryWorker.JobSupervisor, name: FaktoryWorker})

      expect(FaktoryWorker.SocketMock, :connect, fn _host, _port, _opts ->
        {:error, :econnrefused}
      end)

      opts = [
        process_wid: Random.process_wid(),
        retry_interval: 1,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      state = Worker.new(opts)

      Worker.handle_fetch_response({:error, "Failed to connect to Faktory"}, state)

      assert_receive {[:faktory_worker, :fetch], outcome, metadata}
      assert outcome == %{status: {:error, "Failed to connect to Faktory"}}

      assert metadata == %{
               wid: state.process_wid
             }

      assert_receive :fetch

      detach_event_handler(event_handler_id)
    end
  end

  describe "ack_job/2" do
    defp new_running_worker(opts, %{"jid" => jid} = job) do
      opts
      |> Worker.new()
      |> Map.put(:job_id, jid)
      |> Map.put(:job_ref, :erlang.make_ref())
      |> Map.put(:job, job)
      |> Map.put(:worker_state, :running_job)
    end

    test "should send a successful 'ACK' to faktory" do
      job_id = Random.string()

      job = %{
        "args" => [%{"hey" => "there!"}],
        "created_at" => "2019-04-09T12:14:07.6550641Z",
        "enqueued_at" => "2019-04-09T12:14:07.6550883Z",
        "jid" => job_id,
        "jobtype" => "FaktoryWorker.TestQueueWorker",
        "queue" => "test_queue"
      }

      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> new_running_worker(job)
        |> Worker.ack_job(:ok)

      assert result.worker_state == :ok
      assert result.job_ref == nil
      assert result.job_id == nil
      assert result.job_timeout_ref == nil
    end

    test "should execute an event for a successful 'ACK' was sent to faktory" do
      event_handler_id = attach_event_handler([:ack])
      job_id = Random.string()

      job = %{
        "args" => [%{"hey" => "there!"}],
        "created_at" => "2019-04-09T12:14:07.6550641Z",
        "enqueued_at" => "2019-04-09T12:14:07.6550883Z",
        "jid" => job_id,
        "jobtype" => "FaktoryWorker.TestQueueWorker",
        "queue" => "test_queue"
      }

      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> new_running_worker(job)
      |> Worker.ack_job(:ok)

      assert_receive {[:faktory_worker, :ack], outcome, metadata}
      assert outcome == %{status: :ok}

      assert metadata == %{
               jid: job_id,
               args: [%{"hey" => "there!"}],
               jobtype: "FaktoryWorker.TestQueueWorker"
             }

      detach_event_handler(event_handler_id)
    end

    test "should schedule the next fetch for a successful ack" do
      job_id = Random.string()
      job = %{"jid" => job_id}

      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> new_running_worker(job)
      |> Worker.ack_job(:ok)

      assert_receive :fetch
    end

    test "should send a 'FAIL' to faktory for an unsuccessful job" do
      job_id = Random.string()
      job = %{"jid" => job_id}

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
        process_wid: Random.process_wid(),
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      error = {%RuntimeError{message: "It went bang!"}, stacktrace}

      result =
        opts
        |> new_running_worker(job)
        |> Worker.ack_job({:error, error})

      assert result.worker_state == :ok
      assert result.job_ref == nil
      assert result.job_id == nil
      assert result.job == nil
      assert result.job_timeout_ref == nil
    end

    test "should execute event for a 'FAIL' was sent to faktory" do
      event_handler_id = attach_event_handler([:ack])
      job_id = Random.string()

      job = %{
        "args" => [%{"hey" => "there!"}],
        "created_at" => "2019-04-09T12:14:07.6550641Z",
        "enqueued_at" => "2019-04-09T12:14:07.6550883Z",
        "jid" => job_id,
        "jobtype" => "FaktoryWorker.TestQueueWorker",
        "queue" => "test_queue"
      }

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
        process_wid: Random.process_wid(),
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      error = {%RuntimeError{message: "It went bang!"}, stacktrace}

      opts
      |> new_running_worker(job)
      |> Worker.ack_job({:error, error})

      assert_receive {[:faktory_worker, :ack], outcome, metadata}
      assert outcome == %{status: :error}

      assert metadata == %{
               jid: job_id,
               args: [%{"hey" => "there!"}],
               jobtype: "FaktoryWorker.TestQueueWorker"
             }

      detach_event_handler(event_handler_id)
    end

    test "should schedule the next fetch for an unsuccessful ack" do
      job_id = Random.string()
      job = %{"jid" => job_id}

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
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      error = {%RuntimeError{message: "It went bang!"}, stacktrace}

      opts
      |> new_running_worker(job)
      |> Worker.ack_job({:error, error})

      assert_receive :fetch
    end

    test "should execute an event when there was an error sending the ack" do
      event_handler_id = attach_event_handler([:failed_ack])

      job_id = Random.string()

      job = %{
        "jid" => job_id,
        "args" => [%{"hey" => "there!"}],
        "jobtype" => "FaktoryWorker.TestQueueWorker"
      }

      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      FaktoryWorker.SocketMock
      |> expect(:send, fn _, ^ack_command -> :ok end)
      |> expect(:recv, fn _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)

      # the connection manager retries a failed request once
      worker_connection_mox()

      FaktoryWorker.SocketMock
      |> expect(:send, fn _, ^ack_command -> :ok end)
      |> expect(:recv, fn _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)

      opts = [
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> new_running_worker(job)
      |> Worker.ack_job(:ok)

      consume_initial_fetch_message()

      assert_receive {[:faktory_worker, :failed_ack], outcome, metadata}
      assert outcome == %{status: :ok}

      assert metadata == %{
               jid: job_id,
               args: [%{"hey" => "there!"}],
               jobtype: "FaktoryWorker.TestQueueWorker"
             }

      assert_receive :fetch

      detach_event_handler(event_handler_id)
    end

    test "should execute an event when there was an error sending the fail" do
      event_handler_id = attach_event_handler([:failed_ack])

      job_id = Random.string()

      job = %{
        "jid" => job_id,
        "args" => [%{"hey" => "there!"}],
        "jobtype" => "FaktoryWorker.TestQueueWorker"
      }

      fail_payload = %{
        jid: job_id,
        errtype: "Undetected Error Type",
        message: "exit",
        backtrace: []
      }

      fail_command = "FAIL #{Jason.encode!(fail_payload)}\r\n"

      worker_connection_mox()

      FaktoryWorker.SocketMock
      |> expect(:send, fn _, ^fail_command -> :ok end)
      |> expect(:recv, fn _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)

      # the connection manager retries a failed request one more time
      worker_connection_mox()

      FaktoryWorker.SocketMock
      |> expect(:send, fn _, ^fail_command -> :ok end)
      |> expect(:recv, fn _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)

      opts = [
        process_wid: Random.process_wid(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      opts
      |> new_running_worker(job)
      |> Worker.ack_job({:error, :exit})

      consume_initial_fetch_message()

      assert_receive {[:faktory_worker, :failed_ack], outcome, metadata}
      assert outcome == %{status: :error}

      assert metadata == %{
               jid: job_id,
               args: [%{"hey" => "there!"}],
               jobtype: "FaktoryWorker.TestQueueWorker"
             }

      assert_receive :fetch

      detach_event_handler(event_handler_id)
    end

    test "should cancel the job timeout when acknowledging a successful job" do
      job_id = Random.string()
      job = %{"jid" => job_id}

      ack_command = "ACK {\"jid\":\"#{job_id}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^ack_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [
        process_wid: Random.process_wid(),
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      timer_ref = Process.send_after(self(), :test_message, 5000)

      result =
        opts
        |> new_running_worker(job)
        |> Map.put(:job_timeout_ref, timer_ref)
        |> Worker.ack_job(:ok)

      assert result.job_timeout_ref == nil
      assert Process.cancel_timer(timer_ref) == false
    end

    test "should cancel the job timeout when acknowledging a failed job" do
      job_id = Random.string()
      job = %{"jid" => job_id}

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
        process_wid: Random.process_wid(),
        disable_fetch: true,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      error = {%RuntimeError{message: "It went bang!"}, stacktrace}
      timer_ref = Process.send_after(self(), :test_message, 5000)

      result =
        opts
        |> new_running_worker(job)
        |> Map.put(:job_timeout_ref, timer_ref)
        |> Worker.ack_job({:error, error})

      assert result.job_timeout_ref == nil
      assert Process.cancel_timer(timer_ref) == false
    end
  end

  describe "checkin_queues/1" do
    test "should checkin the queues with the queue manager" do
      worker_pool = [queues: [{"test_queue", max_concurrency: 1}]]

      pid = start_supervised!({QueueManager, name: FaktoryWorker, worker_pool: worker_pool})

      state = %{faktory_name: FaktoryWorker, queues: QueueManager.checkout_queues(pid)}
      manager_state_before = :sys.get_state(pid)

      Worker.checkin_queues(state)

      manager_state_after = :sys.get_state(pid)

      assert manager_state_before == [%QueueManager.Queue{name: "test_queue", max_concurrency: 0}]
      assert manager_state_after == [%QueueManager.Queue{name: "test_queue", max_concurrency: 1}]
    end

    test "should return ok when queues are nil" do
      worker_pool = [queues: [{"test_queue", max_concurrency: 1}]]

      pid = start_supervised!({QueueManager, name: FaktoryWorker, worker_pool: worker_pool})

      state = %{faktory_name: FaktoryWorker, queues: nil}
      manager_state_before = :sys.get_state(pid)

      :ok = Worker.checkin_queues(state)

      manager_state_after = :sys.get_state(pid)

      assert manager_state_before == [%QueueManager.Queue{name: "test_queue", max_concurrency: 1}]
      assert manager_state_after == [%QueueManager.Queue{name: "test_queue", max_concurrency: 1}]
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
