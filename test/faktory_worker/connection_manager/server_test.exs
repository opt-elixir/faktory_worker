defmodule FaktoryWorker.ConnectionManager.ServerTest do
  use ExUnit.Case

  import Mox
  import FaktoryWorker.ConnectionHelpers

  alias FaktoryWorker.Random
  alias FaktoryWorker.ConnectionManager.Server

  setup :set_mox_global
  setup :verify_on_exit!

  describe "send_command/3" do
    test "should handle server timeouts for fetch commands" do
      worker_connection_mox()

      expect(FaktoryWorker.SocketMock, :send, fn _, _ ->
        # sleep to make sure the fetch command takes longer
        # than the genserver timeout specified below
        Process.sleep(10)
        {:ok, "$-1"}
      end)

      opts = [
        is_worker: true,
        process_wid: Random.process_wid(),
        socket_handler: FaktoryWorker.SocketMock
      ]

      timeout = 1

      pid = start_supervised!({Server, opts})

      result = Server.send_command(pid, {:fetch, ["default"]}, timeout)

      assert result == {:error, :timeout}
    end

    test "should return error when connection manager is dead (noproc)" do
      pid = spawn(fn -> :ok end)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}

      assert Server.send_command(pid, {:fetch, ["default"]}) == {:error, :connection_dead}
    end

    test "should return error when connection manager is dead for ack commands" do
      pid = spawn(fn -> :ok end)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}

      assert Server.send_command(pid, {:ack, "some_jid"}) == {:error, :connection_dead}
    end

    test "should return error when connection manager is dead for fail commands" do
      pid = spawn(fn -> :ok end)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}

      payload = %{jid: "some_jid", errtype: "Error", message: "boom", backtrace: []}
      assert Server.send_command(pid, {:fail, payload}) == {:error, :connection_dead}
    end

    test "should return error when connection manager shuts down during call" do
      worker_connection_mox()

      opts = [
        is_worker: true,
        process_wid: Random.process_wid(),
        socket_handler: FaktoryWorker.SocketMock
      ]

      pid = start_supervised!({Server, opts})
      # Stop the process to simulate shutdown
      stop_supervised!(Server)

      assert Server.send_command(pid, {:fetch, ["default"]}) == {:error, :connection_dead}
    end
  end

  describe "handle_info/2" do
    test "should handle the ssl_closed error message" do
      # the nil values in this error are replacing implementation details in the :ssl module
      # and are not used by the server
      error =
        {:ssl_closed, {:sslsocket, {:gen_tcp, nil, :tls_connection, :undefined}, [nil, nil]}}

      state = %FaktoryWorker.ConnectionManager{
        conn: %FaktoryWorker.Connection{
          host: "localhost",
          port: 7419,
          socket: :fake_socket,
          socket_handler: FaktoryWorker.Socket.Ssl
        }
      }

      {:stop, :normal, new_state} = Server.handle_info(error, state)

      assert new_state.conn == nil
    end
  end
end
