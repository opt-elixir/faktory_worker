defmodule FaktoryWorker.Connection do
  @moduledoc false

  alias FaktoryWorker.Connection
  alias FaktoryWorker.Socket.Tcp
  alias FaktoryWorker.Protocol

  @faktory_version 2

  @enforce_keys [:host, :port, :socket, :socket_handler]
  defstruct [:host, :port, :socket, :socket_handler]

  @spec open(opts :: keyword()) :: {:ok, %Connection{}} | {:error, term()}
  def open(opts \\ []) do
    socket_handler = Keyword.get(opts, :socket_handler, Tcp)
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 7419)

    with {:ok, connection} <- socket_handler.connect(host, port),
         :ok <- verify_faktory_version(connection),
         :ok <- verify_hello_response(connection) do
      {:ok, connection}
    end
  end

  def send_command(%{socket_handler: socket_handler} = connection, command) do
    case Protocol.encode_command(command) do
      {:ok, payload} -> socket_handler.send(connection, payload)
      error -> error
    end
  end

  def recv(%{socket_handler: socket_handler} = connection) do
    socket_handler.recv(connection)
  end

  defp verify_faktory_version(connection) do
    case recv(connection) do
      {:ok, response} ->
        response
        |> Protocol.decode_response()
        |> verify_version()

      error ->
        error
    end
  end

  defp verify_version({:ok, %{"v" => @faktory_version}}), do: :ok

  defp verify_version({:ok, %{"v" => version}}) do
    {:error,
     "Only Faktory version '#{@faktory_version}' is supported (connected to Faktory version '#{
       version
     }')."}
  end

  defp verify_hello_response(connection) do
    with :ok <- send_command(connection, {:hello, @faktory_version}),
         {:ok, response} <- recv(connection),
         {:ok, "OK"} <- Protocol.decode_response(response) do
      :ok
    end
  end
end
