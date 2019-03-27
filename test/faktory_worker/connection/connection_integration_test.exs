defmodule FaktoryWorker.Connection.ConnectionIntegrationTest do
  use ExUnit.Case, async: true

  alias FaktoryWorker.Connection

  @passworded_connection_opts Application.get_env(:faktory_worker, :passworded_server)
  @tls_connection_opts Application.get_env(:faktory_worker, :tls_server)

  describe "open/1" do
    test "should return a connection to faktory" do
      {:ok, %Connection{} = connection} = Connection.open()

      assert connection.host == "localhost"
      assert connection.port == 7419
      assert connection.socket_handler == FaktoryWorker.Socket.Tcp
      assert is_port(connection.socket)
    end

    test "should return a connection to a password protected faktory" do
      {:ok, %Connection{} = connection} =
        Connection.open([password: "very-secret"] ++ @passworded_connection_opts)

      assert connection.host == @passworded_connection_opts[:host]
      assert connection.port == @passworded_connection_opts[:port]
      assert connection.socket_handler == FaktoryWorker.Socket.Tcp
      assert is_port(connection.socket)
    end

    test "should return an invalid password error when connection to a password protected faktory" do
      {:error, reason} =
        Connection.open([password: "wrong-password"] ++ @passworded_connection_opts)

      assert reason == "Invalid password"
    end

    test "should return a tls connection to faktory" do
      {:ok, %Connection{} = connection} =
        Connection.open([use_tls: true, tls_verify: false] ++ @tls_connection_opts)

      assert connection.host == @tls_connection_opts[:host]
      assert connection.port == @tls_connection_opts[:port]
      assert connection.socket_handler == FaktoryWorker.Socket.Ssl

      {:sslsocket, {_, socket_port, :tls_connection, _}, _} = connection.socket
      assert is_port(socket_port)
    end

    test "should return error when failing to connect" do
      opts = [host: "non-existent-host"]
      {:error, reason} = Connection.open(opts)

      assert reason == :nxdomain
    end
  end
end
