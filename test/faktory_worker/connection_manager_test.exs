defmodule FaktoryWorker.ConnectionManagerTest do
  use ExUnit.Case

  import Mox
  import FaktoryWorker.ConnectionHelpers
  import ExUnit.CaptureLog

  alias FaktoryWorker.Connection
  alias FaktoryWorker.ConnectionManager

  setup :verify_on_exit!

  describe "new/1" do
    test "should return a new connection manager struct" do
      connection_mox()

      opts = [socket_handler: FaktoryWorker.SocketMock]

      %ConnectionManager{opts: connection_opts, conn: connection} = ConnectionManager.new(opts)

      assert connection_opts == opts

      assert connection == %Connection{
               host: "localhost",
               port: 7419,
               socket: :test_socket,
               socket_handler: FaktoryWorker.SocketMock
             }
    end

    test "should return a new connection manager with nil connection when socket failed to connect" do
      expect(FaktoryWorker.SocketMock, :connect, fn _, _, _ ->
        {:error, :econnrefused}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]

      %ConnectionManager{opts: connection_opts, conn: connection} = ConnectionManager.new(opts)

      assert connection_opts == opts
      assert connection == nil
    end
  end

  describe "send_command/2" do
    test "should be able to send a command" do
      connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "INFO\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]
      state = ConnectionManager.new(opts)

      {{:ok, result}, _} = ConnectionManager.send_command(state, :info)

      assert result == "OK"
    end

    test "should not retry a job that halts" do
      payload = %{
        args: [1],
        jid: "123456",
        jobtype: "TestJob",
        queue: "test_queue"
      }

      json = Jason.encode!(payload)
      command = "PUSH #{json}\r\n"

      connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:error, "Halt: halt reason"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]
      state = ConnectionManager.new(opts)

      # By receiving :ok, the job will not be retried
      assert capture_log(fn ->
               {{:ok, result}, _} = ConnectionManager.send_command(state, {:push, payload})

               assert result == "halt reason"
             end) |> String.match?(~r/\[warn.*(?<!ing)\]*\[123456\]*[Halt: halt reason]/)
    end

    test "should unset the connection when there is a socket failure" do
      connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "INFO\r\n" ->
        {:error, :closed}
      end)

      expect(FaktoryWorker.SocketMock, :connect, fn _, _, _ ->
        {:error, :econnrefused}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]
      state = ConnectionManager.new(opts)

      {{:error, error}, state} = ConnectionManager.send_command(state, :info)

      assert error == "Failed to connect to Faktory"
      assert state.conn == nil
    end

    test "should open a new connection when no connection exists" do
      connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "INFO\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]
      state = %ConnectionManager{opts: opts, conn: nil}

      {{:ok, result}, state} = ConnectionManager.send_command(state, :info)

      assert result == "OK"

      assert state.conn == %Connection{
               host: "localhost",
               port: 7419,
               socket: :test_socket,
               socket_handler: FaktoryWorker.SocketMock
             }
    end

    test "should return an error if the connection still can't be opened" do
      expect(FaktoryWorker.SocketMock, :connect, fn _, _, _ ->
        {:error, :econnrefused}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]
      state = %ConnectionManager{opts: opts, conn: nil}

      {{:error, error}, state} = ConnectionManager.send_command(state, :info)

      assert error == "Failed to connect to Faktory"
      assert state.conn == nil
    end

    test "should attempt reconnect and resend the command once if the first attemp failed" do
      expect(FaktoryWorker.SocketMock, :send, fn _, _ ->
        {:error, :closed}
      end)

      connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, _ ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]

      state = %ConnectionManager{
        opts: opts,
        conn: %Connection{
          host: "localhost",
          port: 7419,
          socket: :test_socket,
          socket_handler: FaktoryWorker.SocketMock
        }
      }

      {{:ok, result}, state} = ConnectionManager.send_command(state, :info)

      assert result == "OK"

      assert state.conn == %Connection{
               host: "localhost",
               port: 7419,
               socket: :test_socket,
               socket_handler: FaktoryWorker.SocketMock
             }
    end

    test "should unset the connection state when receiving an expected close response" do
      connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "END\r\n" ->
        :ok
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]
      state = ConnectionManager.new(opts)

      {{:ok, :closed}, state} = ConnectionManager.send_command(state, :end)

      assert state.conn == nil
    end

    test "should return a not unique error" do
      payload = %{
        args: [1],
        jid: "123456",
        jobtype: "TestJob",
        queue: "test_queue"
      }

      json = Jason.encode!(payload)
      command = "PUSH #{json}\r\n"

      connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, ^command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "-NOTUNIQUE Job not unique\r\n"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]
      state = ConnectionManager.new(opts)

      {result, _} = ConnectionManager.send_command(state, {:push, payload})

      assert result == {:error, :not_unique}
    end
  end
end
