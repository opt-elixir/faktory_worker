defmodule FaktoryWorker.Connection.ConnectionTest do
  use ExUnit.Case

  import Mox

  alias FaktoryWorker.Connection
  alias FaktoryWorker.Socket

  setup :verify_on_exit!

  describe "open/1" do
    test "should open a faktory connection with the default config" do
      opts = [socket_module: FaktoryWorker.SocketMock]

      expect(FaktoryWorker.SocketMock, :connect, fn host, port ->
        {:ok, %Socket{host: host, port: port, socket: :test_socket}}
      end)

      {:ok, %Socket{} = connection} = Connection.open(opts)

      assert connection.host == "localhost"
      assert connection.port == 7419
      assert connection.socket == :test_socket
    end

    test "should open a faktory connection with user defined config" do
      opts = [host: "test-host", port: 5002, socket_module: FaktoryWorker.SocketMock]

      expect(FaktoryWorker.SocketMock, :connect, fn host, port ->
        {:ok, %Socket{host: host, port: port, socket: :test_socket}}
      end)

      {:ok, %Socket{} = connection} = Connection.open(opts)

      assert connection.host == "test-host"
      assert connection.port == 5002
      assert connection.socket == :test_socket
    end
  end
end
