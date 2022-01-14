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

  defmacro worker_connection_mox() do
    quote do
      {:ok, expected_host} = :inet.gethostname()
      expected_sys_pid = System.pid()
      runtime_vsn = System.version()

      expect(FaktoryWorker.SocketMock, :connect, fn host, port, _ ->
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

      expect(FaktoryWorker.SocketMock, :send, fn _, "HELLO " <> rest ->
        args =
          rest
          |> String.trim_trailing("\r\n")
          |> Jason.decode!()

        assert args["hostname"] == to_string(expected_host)
        assert args["pid"] == String.to_integer(expected_sys_pid)
        assert args["labels"] == ["elixir-#{runtime_vsn}"]
        assert String.length(args["wid"]) == 16
        assert args["v"] == 2

        :ok
      end)

      expect(FaktoryWorker.SocketMock, :recv, fn _ ->
        {:ok, "+OK\r\n"}
      end)
    end
  end

  defmacro connection_close_mox() do
    quote do
      expect(FaktoryWorker.SocketMock, :send, fn _, "END\r\n" ->
        :ok
      end)
    end
  end
end
