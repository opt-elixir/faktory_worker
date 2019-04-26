defmodule FaktoryWorker.Connection.Socket.SslTest do
  use ExUnit.Case, async: true

  alias FaktoryWorker.Connection
  alias FaktoryWorker.Socket.Ssl

  @tls_host Application.get_env(:faktory_worker, :tls_server)[:host]
  @tls_port Application.get_env(:faktory_worker, :tls_server)[:port]

  describe "connect/3" do
    test "should open a ssl socket to faktory" do
      opts = [tls_verify: false]
      {:ok, %Connection{} = connection} = Ssl.connect(@tls_host, @tls_port, opts)

      assert connection.host == @tls_host
      assert connection.port == @tls_port
      assert connection.socket_handler == Ssl

      {:sslsocket, {_, socket_port, :tls_connection, _}, _} = connection.socket
      assert is_port(socket_port)
    end

    test "should return error when failing to connect" do
      {:error, reason} = Ssl.connect("non-existent-host", @tls_port)

      assert reason == :nxdomain
    end
  end

  describe "send/1" do
    test "should be able to send a packet to faktory" do
      opts = [tls_verify: false]
      {:ok, %Connection{} = connection} = Ssl.connect(@tls_host, @tls_port, opts)
      # need to receive the HELLO response before we can send
      {:ok, _} = Ssl.recv(connection)

      :ok = Ssl.send(connection, "HELLO {\"v\":2}\r\n")

      # if we have sent the packet correctly we should get an OK response
      {:ok, response} = Ssl.recv(connection)

      assert response == "+OK\r\n"
    end
  end

  describe "recv/1" do
    test "should be able to receive a packet from faktory" do
      opts = [tls_verify: false]
      {:ok, %Connection{} = connection} = Ssl.connect(@tls_host, @tls_port, opts)
      {:ok, result} = Ssl.recv(connection)

      assert result == "+HI {\"v\":2}\r\n"
    end
  end

  describe "recv/2" do
    test "should be able to receive a raw packet from faktory" do
      opts = [tls_verify: false]
      {:ok, %Connection{} = connection} = Ssl.connect(@tls_host, @tls_port, opts)
      {:ok, result} = Ssl.recv(connection, 13)

      assert result == "+HI {\"v\":2}\r\n"
    end
  end
end
