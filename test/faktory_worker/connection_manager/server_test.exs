defmodule FaktoryWorker.ConnectionManager.ServerTest do
  use ExUnit.Case

  import Mox

  alias FaktoryWorker.ConnectionManager.Server

  setup :set_mox_global
  setup :verify_on_exit!

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
