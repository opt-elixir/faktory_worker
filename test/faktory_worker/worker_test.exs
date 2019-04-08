defmodule FaktoryWorker.WorkerTest do
  use ExUnit.Case, async: true

  import Mox
  import FaktoryWorker.ConnectionHelpers

  alias FaktoryWorker.Worker
  alias FaktoryWorker.Random

  @fifteen_seconds 15_000

  setup :verify_on_exit!

  describe "new/2" do
    test "should return a worker struct" do
      worker_id = Random.worker_id()
      opts = [worker_id: worker_id]

      worker = Worker.new(opts, self())

      assert worker.worker_id == worker_id
      assert worker.worker_state == :ok
      assert worker.worker_server == self()
      assert worker.beat_interval == @fifteen_seconds
    end

    test "should raise if no worker id is provided" do
      assert_raise KeyError, fn ->
        Worker.new([], self())
      end
    end

    test "should open a new worker connection" do
      worker_connection_mox()

      opts = [
        worker_id: Random.worker_id(),
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker = Worker.new(opts, self())

      assert worker.conn != nil
    end

    test "should schedule a beat to be triggered" do
      opts = [worker_id: Random.worker_id()]

      worker = Worker.new(opts, self())

      assert is_reference(worker.beat_ref)
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
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker = Worker.new(opts, self())

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
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker =
        opts
        |> Worker.new(self())
        |> Map.put(:worker_state, :quiet)

      result = Worker.send_beat(worker)

      assert is_reference(result.beat_ref)
      assert result.beat_ref != worker.beat_ref
    end

    test "should not send a beat command or schedule a next beat when state is ':terminate'" do
      worker_id = Random.worker_id()

      worker_connection_mox()

      opts = [
        worker_id: worker_id,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      worker =
        opts
        |> Worker.new(self())
        |> Map.put(:worker_state, :terminate)

      result = Worker.send_beat(worker)

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
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new(self())
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
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      result =
        opts
        |> Worker.new(self())
        |> Worker.send_beat()

      assert result.worker_state == :terminate
    end
  end
end
