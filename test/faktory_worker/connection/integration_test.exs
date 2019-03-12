defmodule FaktoryWorker.Connection.IntegrationTest do
  use ExUnit.Case

  alias FaktoryWorker.Socket
  alias FaktoryWorker.Connection

  describe "open/1" do
    test "should return a connection to faktory" do
      {:ok, %Socket{} = connection} = Connection.open()

      assert connection.host == "localhost"
      assert connection.port == 7419
      assert is_port(connection.socket)
    end

    test "should return error when failing to connect" do
      opts = [host: "non-existent-host"]
      {:error, reason} = Connection.open(opts)

      assert reason == :nxdomain
    end
  end
end
