defmodule FaktoryWorker.Connection.Socket.TcpTest do
  use ExUnit.Case, async: true

  alias FaktoryWorker.Connection
  alias FaktoryWorker.Socket.Tcp

  describe "connect/2" do
    test "should open a socket to faktory" do
      {:ok, %Connection{} = connection} = Tcp.connect("localhost", 7419)

      assert connection.host == "localhost"
      assert connection.port == 7419
      assert connection.socket_handler == Tcp
      assert is_port(connection.socket)
    end

    test "should return error when failing to connect" do
      {:error, reason} = Tcp.connect("non-existent-host", 7419)

      assert reason == :nxdomain
    end
  end

  describe "send/1" do
    test "should be able to send a packet to faktory" do
      {:ok, %Connection{} = connection} = Tcp.connect("localhost", 7419)
      # need to receive the HELLO response before we can send
      {:ok, _} = Tcp.recv(connection)

      :ok = Tcp.send(connection, "HELLO {\"v\":2}\r\n")

      # if we have sent the packet correctly we should get an OK response
      {:ok, response} = Tcp.recv(connection)

      assert response == "+OK\r\n"
    end
  end

  describe "recv/1" do
    test "should be able to receive a packet from faktory" do
      {:ok, %Connection{} = connection} = Tcp.connect("localhost", 7419)
      {:ok, result} = Tcp.recv(connection)

      assert result == "+HI {\"v\":2}\r\n"
    end
  end
end
