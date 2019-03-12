defmodule FaktoryWorker.Connection.IntegrationTest do
  use ExUnit.Case, async: true

  alias FaktoryWorker.Connection

  describe "open/1" do
    test "should return a connection to faktory" do
      {:ok, %Connection{} = connection} = Connection.open()

      assert connection.host == "localhost"
      assert connection.port == 7419
      assert connection.socket_handler == FaktoryWorker.Socket.Tcp
      assert is_port(connection.socket)
    end

    test "should return error when failing to connect" do
      opts = [host: "non-existent-host"]
      {:error, reason} = Connection.open(opts)

      assert reason == :nxdomain
    end
  end
end
