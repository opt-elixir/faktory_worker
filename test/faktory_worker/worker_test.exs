defmodule FaktoryWorker.WorkerTest do
  use ExUnit.Case, async: true

  import Mox
  import FaktoryWorker.ConnectionHelpers

  alias FaktoryWorker.Worker
  alias FaktoryWorker.Random
  alias FaktoryWorker.{DefaultWorker, TestQueueWorker}

  @two_seconds 2000
  @fifteen_seconds 15_000

  setup :verify_on_exit!

  describe "new/2" do
    test "should return a worker struct" do
      worker_id = Random.worker_id()
      opts = [worker_id: worker_id, worker_module: TestQueueWorker]

      worker = Worker.new(opts)

      assert worker.worker_id == worker_id
      assert worker.worker_state == :ok
      assert worker.beat_interval == @fifteen_seconds
      assert worker.fetch_interval == @two_seconds
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

      worker = Worker.new(opts)

      assert is_reference(worker.fetch_ref)
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

      worker = Worker.new(opts)

      result = Worker.send_fetch(worker)

      assert is_reference(result.fetch_ref)
      assert result.fetch_ref != worker.fetch_ref
    end

    test "should not send a fetch command and schedule next fetch when state is ':quiet'" do
      worker_connection_mox()

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Map.put(:worker_state, :quiet)
        |> Worker.send_fetch()

      assert result.fetch_ref == nil
    end

    test "should not send a fetch command and schedule next fetch when state is ':terminate'" do
      worker_connection_mox()

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Map.put(:worker_state, :terminate)
        |> Worker.send_fetch()

      assert result.fetch_ref == nil
    end

    test "should not send a fetch command and schedule next fetch when state is ':running_job'" do
      worker_connection_mox()

      opts = [
        worker_id: Random.worker_id(),
        worker_module: TestQueueWorker,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new()
        |> Map.put(:worker_state, :running_job)
        |> Worker.send_fetch()

      assert result.fetch_ref == nil
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
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "FETCH test_queue\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$212\r\n"}
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _, _ ->
        job =
          Jason.encode!(%{
            "args" => [%{"hey" => "there!"}],
            "created_at" => "2019-04-09T12:14:07.6550641Z",
            "enqueued_at" => "2019-04-09T12:14:07.6550883Z",
            "jid" => "f47ccc395ef9d9646118434f",
            "jobtype" => "FaktoryWorker.TestQueueWorker",
            "queue" => "test_queue"
          })

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
    end
  end
end
