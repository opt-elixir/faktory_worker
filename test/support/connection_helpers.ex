defmodule FaktoryWorker.ConnectionHelpers do
  @moduledoc false

  defmacro connection_mox() do
    quote do
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
        {:ok, "+HI {\"v\":2}\r\n"}
      end)

      expect(FaktoryWorker.SocketMock, :send, fn _, "HELLO {\"v\":2}\r\n" ->
        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)
    end
  end
end
