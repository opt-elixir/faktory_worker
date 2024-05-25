defmodule FaktoryWorker.Connection.ConnectionTest do
  use ExUnit.Case, async: true

  import Mox
  import FaktoryWorker.ConnectionHelpers

  alias FaktoryWorker.Connection
  alias FaktoryWorker.Random

  setup :verify_on_exit!

  describe "open/1" do
    test "should open and setup a faktory connection with the default config" do
      connection_mox()

      opts = [socket_handler: FaktoryWorker.SocketMock]

      {:ok, %Connection{} = connection} = Connection.open(opts)

      assert connection.host == "localhost"
      assert connection.port == 7419
      assert connection.socket == :test_socket
    end

    test "should open and setup a faktory connection with user defined config" do
      connection_mox()

      opts = [host: "test-host", port: 5002, socket_handler: FaktoryWorker.SocketMock]

      {:ok, %Connection{} = connection} = Connection.open(opts)

      assert connection.host == "test-host"
      assert connection.port == 5002
      assert connection.socket == :test_socket
    end

    test "should support connecting to a password protected faktory server" do
      expected_hello_command =
        "HELLO {\"pwdhash\":\"b8735599d9a3747a180d8db1e4ca5e3e2079d6eb0c19ab637b4145c9dccb9958\",\"v\":2}\r\n"

      expect(FaktoryWorker.SocketMock, :connect, fn host, port, _ ->
        {:ok,
         %FaktoryWorker.Connection{
           host: host,
           port: port,
           socket: :test_socket,
           socket_handler: FaktoryWorker.SocketMock
         }}
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+HI {\"v\":2,\"i\":7042,\"s\":\"1a02070f169c1121\"}\r\n"}
      end)

      expect(FaktoryWorker.SocketMock, :send, fn _, ^expected_hello_command ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)

      opts = [password: "some-password", socket_handler: FaktoryWorker.SocketMock]

      assert {:ok, %Connection{}} = Connection.open(opts)
    end

    test "should register the connection as a worker" do
      worker_connection_mox()

      opts = [
        is_worker: true,
        process_wid: Random.process_wid(),
        socket_handler: FaktoryWorker.SocketMock
      ]

      assert {:ok, %Connection{}} = Connection.open(opts)
    end

    test "should be able to set custom worker labels" do
      worker_connection_mox(labels: ["service-xyz"])

      opts = [
        is_worker: true,
        labels: ["service-xyz"],
        process_wid: Random.process_wid(),
        socket_handler: FaktoryWorker.SocketMock
      ]

      assert {:ok, %Connection{}} = Connection.open(opts)
    end

    test "should return an error if the returned faktory version is not supported" do
      opts = [socket_handler: FaktoryWorker.SocketMock]

      expect(FaktoryWorker.SocketMock, :connect, fn host, port, _opts ->
        {:ok,
         %Connection{
           host: host,
           port: port,
           socket: :test_socket,
           socket_handler: FaktoryWorker.SocketMock
         }}
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+HI {\"v\":1}\r\n"}
      end)

      {:error, reason} = Connection.open(opts)

      assert reason == "Only Faktory version '2' is supported (connected to Faktory version '1')."
    end

    test "should return a socket error" do
      opts = [socket_handler: FaktoryWorker.SocketMock]

      expect(FaktoryWorker.SocketMock, :connect, fn _, _, _ ->
        {:error, :econnrefused}
      end)

      {:error, reason} = Connection.open(opts)

      assert reason == :econnrefused
    end
  end

  describe "send_command/2" do
    test "should call into the socket handler" do
      expect(FaktoryWorker.SocketMock, :send, fn _, "HELLO {\"v\":1}\r\n" ->
        :called_handler
      end)

      connection = %Connection{
        host: "localhost",
        port: 1234,
        socket: :test_socket,
        socket_handler: FaktoryWorker.SocketMock
      }

      assert :called_handler == Connection.send_command(connection, {:hello, %{v: 1}})
    end

    test "should receive the result of a bulk string response from faktory" do
      connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "INFO\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "$37\r\n"}
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _, 39 ->
        {:ok, "{\"some\":\"longer\",\"response\":\"data\"}\r\n"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]

      {:ok, connection} = Connection.open(opts)
      {:ok, result} = Connection.send_command(connection, :info)

      assert result == %{"response" => "data", "some" => "longer"}
    end

    test "should return an error if there was a socket connection issue" do
      connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "INFO\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:error, :closed}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]

      {:ok, connection} = Connection.open(opts)

      assert {:error, :closed} == Connection.send_command(connection, :info)
    end

    test "should return an error if an error occurs during the connection handshake" do
      expect(FaktoryWorker.SocketMock, :connect, fn host, port, _opts ->
        {:ok,
         %FaktoryWorker.Connection{
           host: host,
           port: port,
           socket: :test_socket,
           socket_handler: FaktoryWorker.SocketMock
         }}
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "-ERR Something went wrong\r\n"}
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]

      {:error, reason} = Connection.open(opts)

      assert reason == "Something went wrong"
    end

    test "should not call recv function when sending an END command" do
      connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, "END\r\n" ->
        :ok
      end)

      opts = [socket_handler: FaktoryWorker.SocketMock]

      {:ok, connection} = Connection.open(opts)
      {:ok, result} = Connection.send_command(connection, :end)

      assert result == :closed
    end
  end
end
