defmodule FaktoryWorker.Worker.HeartbeatServerTest do
  use ExUnit.Case

  import Mox
  import FaktoryWorker.ConnectionHelpers
  import FaktoryWorker.EventHandlerTestHelpers

  alias FaktoryWorker.Random
  alias FaktoryWorker.ConnectionManager
  alias FaktoryWorker.Worker.HeartbeatServer

  setup :set_mox_global
  setup :verify_on_exit!

  describe "child_spec/1" do
    test "should return the child spec" do
      opts = [name: FaktoryWorker]

      child_spec = HeartbeatServer.child_spec(opts)

      assert child_spec == %{
               id: FaktoryWorker_heartbeat_server,
               start: {HeartbeatServer, :start_link, [opts]},
               type: :worker
             }
    end
  end

  describe "start_link/1" do
    test "should start hearbeat server" do
      opts = [name: FaktoryWorker]

      {:ok, pid} = HeartbeatServer.start_link(opts)

      assert pid == Process.whereis(FaktoryWorker_heartbeat_server)

      :ok = Supervisor.stop(pid)
    end
  end

  describe "init/1" do
    test "should setup the initial state and trigger the connection setup" do
      process_wid = Random.process_wid()
      opts = [name: FaktoryWorker, process_wid: process_wid]

      {:ok, state, continue} = HeartbeatServer.init(opts)

      assert state == %{
               name: FaktoryWorker,
               process_wid: process_wid,
               beat_interval: 15_000,
               beat_state: :ok,
               beat_ref: nil,
               conn: nil
             }

      assert continue == {:continue, {:setup_connection, opts}}
    end
  end

  describe "handle_continue/2" do
    test "should setup the connection and trigger the first beat" do
      process_wid = Random.process_wid()
      opts = [name: FaktoryWorker, process_wid: process_wid]

      state = %{
        process_wid: process_wid,
        beat_state: :ok,
        beat_ref: nil,
        conn: nil
      }

      {:noreply, %{conn: conn}, continue} =
        HeartbeatServer.handle_continue({:setup_connection, opts}, state)

      assert %ConnectionManager{} = conn
      assert continue == {:continue, :schedule_beat}
    end

    test "should schedule a beat" do
      state = %{
        beat_interval: 15_000,
        beat_state: :ok,
        beat_ref: nil
      }

      {:noreply, state} = HeartbeatServer.handle_continue(:schedule_beat, state)

      assert is_reference(state.beat_ref)
    end
  end

  describe "handle_info/2" do
    test "should send a beat when state is ':ok'" do
      process_wid = Random.process_wid()
      beat_command = "BEAT {\"wid\":\"#{process_wid}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock, is_worker: true, process_wid: process_wid]

      state = %{
        name: FaktoryWorker,
        process_wid: process_wid,
        beat_state: :ok,
        beat_ref: :erlang.make_ref(),
        conn: ConnectionManager.new(opts)
      }

      {:noreply, state, continue} = HeartbeatServer.handle_info(:beat, state)

      assert state.beat_state == :ok
      assert state.beat_ref == nil
      assert continue == {:continue, :schedule_beat}
    end

    test "should send a beat when state is ':quiet'" do
      process_wid = Random.process_wid()
      beat_command = "BEAT {\"wid\":\"#{process_wid}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock, is_worker: true, process_wid: process_wid]

      state = %{
        name: FaktoryWorker,
        process_wid: process_wid,
        beat_state: :quiet,
        beat_ref: :erlang.make_ref(),
        conn: ConnectionManager.new(opts)
      }

      {:noreply, state, continue} = HeartbeatServer.handle_info(:beat, state)

      assert state.beat_state == :ok
      assert state.beat_ref == nil
      assert continue == {:continue, :schedule_beat}
    end

    test "should not send a beat for other beat states" do
      process_wid = Random.process_wid()

      worker_connection_mox()

      opts = [socket_handler: FaktoryWorker.SocketMock, is_worker: true, process_wid: process_wid]

      state = %{
        name: FaktoryWorker,
        process_wid: process_wid,
        beat_state: :terminate,
        beat_ref: :erlang.make_ref(),
        conn: ConnectionManager.new(opts)
      }

      {:noreply, state, continue} = HeartbeatServer.handle_info(:beat, state)

      assert state.beat_state == :terminate
      assert state.beat_ref == nil
      assert continue == {:continue, :schedule_beat}
    end

    test "should handle receiving the quiet state response" do
      process_wid = Random.process_wid()
      beat_command = "BEAT {\"wid\":\"#{process_wid}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+{\"state\": \"quiet\"}\r\n"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock, is_worker: true, process_wid: process_wid]

      state = %{
        name: FaktoryWorker,
        process_wid: process_wid,
        beat_state: :ok,
        beat_ref: :erlang.make_ref(),
        conn: ConnectionManager.new(opts)
      }

      {:noreply, state, _} = HeartbeatServer.handle_info(:beat, state)

      assert state.beat_state == :quiet
    end

    test "should handle receiving the terminate state response" do
      process_wid = Random.process_wid()
      beat_command = "BEAT {\"wid\":\"#{process_wid}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+{\"state\": \"terminate\"}\r\n"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock, is_worker: true, process_wid: process_wid]

      state = %{
        name: FaktoryWorker,
        process_wid: process_wid,
        beat_state: :quiet,
        beat_ref: :erlang.make_ref(),
        conn: ConnectionManager.new(opts)
      }

      {:noreply, state, _} = HeartbeatServer.handle_info(:beat, state)

      assert state.beat_state == :terminate
    end

    test "should execute an event when the beat outcome changes" do
      event_handler_id = attach_event_handler([:beat])

      process_wid = Random.process_wid()
      beat_command = "BEAT {\"wid\":\"#{process_wid}\"}\r\n"

      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^beat_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:error, :closed}
      end)

      expect(FaktoryWorker.SocketMock, :connect, fn _, _, _ ->
        {:error, :econnrefused}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock, is_worker: true, process_wid: process_wid]

      state = %{
        name: FaktoryWorker,
        process_wid: process_wid,
        beat_state: :ok,
        beat_ref: :erlang.make_ref(),
        conn: ConnectionManager.new(opts)
      }

      HeartbeatServer.handle_info(:beat, state)

      assert_receive {[:faktory_worker, :beat], outcome, metadata}
      assert outcome == %{status: :error}

      assert metadata == %{
               prev_status: :ok,
               wid: process_wid
             }

      detach_event_handler(event_handler_id)
    end
  end

  describe "terminate/2" do
    test "should send the end command" do
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "END\r\n" ->
        :ok
      end)

      opts = [
        socket_handler: FaktoryWorker.SocketMock,
        is_worker: true,
        process_wid: Random.process_wid()
      ]

      state = %{
        name: FaktoryWorker,
        beat_ref: nil,
        conn: ConnectionManager.new(opts)
      }

      HeartbeatServer.terminate(:shutdown, state)
    end

    test "should cancel the beat timer" do
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "END\r\n" ->
        :ok
      end)

      opts = [
        socket_handler: FaktoryWorker.SocketMock,
        is_worker: true,
        process_wid: Random.process_wid()
      ]

      beat_ref = Process.send_after(self(), :beat, 1000)

      state = %{
        name: FaktoryWorker,
        beat_ref: beat_ref,
        conn: ConnectionManager.new(opts)
      }

      HeartbeatServer.terminate(:shutdown, state)

      assert false == Process.cancel_timer(beat_ref)
    end

    test "should terminate when there is no active connection" do
      state = %{
        name: FaktoryWorker,
        conn: nil
      }

      HeartbeatServer.terminate(:shutdown, state)
    end
  end

  describe "lifecycle" do
    test "should send regular 'BEAT' commands" do
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

      expect(FaktoryWorker.SocketMock, :send, fn _, "END" <> _ ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        # return the terminate state here to prevent futher beat commands
        {:ok, "+{\"state\": \"terminate\"}\r\n"}
      end)

      opts = [
        name: :test,
        process_wid: Random.process_wid(),
        beat_interval: 1,
        connection: [socket_handler: FaktoryWorker.SocketMock]
      ]

      pid = start_supervised!(HeartbeatServer.child_spec(opts))

      %{beat_state: :ok} = :sys.get_state(pid)

      # # sleep 5 milliseconds to allow both beats to occur
      Process.sleep(5)

      :ok = stop_supervised(:test_heartbeat_server)
    end
  end
end
