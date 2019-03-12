defmodule FaktoryWorker.Connection.Socket.TcpTest do
  use ExUnit.Case

  alias FaktoryWorker.Socket
  alias FaktoryWorker.Socket.Tcp

  describe "connect/2" do
    test "should open a socket to faktory" do
      {:ok, %Socket{} = connection} = Tcp.connect("localhost", 7419)

      assert connection.host == "localhost"
      assert connection.port == 7419
      assert is_port(connection.socket)
    end

    test "should be able to receive the 'HI' response from faktory" do
      {:ok, %Socket{} = connection} = Tcp.connect("localhost", 7419)
      {:ok, result} = :gen_tcp.recv(connection.socket, 0)

      assert result == "+HI {\"v\":2}\r\n"
    end

    test "should return error when failing to connect" do
      {:error, reason} = Tcp.connect("non-existent-host", 7419)

      assert reason == :nxdomain
    end
  end
end
