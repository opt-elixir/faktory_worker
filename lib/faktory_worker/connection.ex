defmodule FaktoryWorker.Connection do
  @moduledoc false

  alias FaktoryWorker.Connection
  alias FaktoryWorker.Socket.Tcp
  alias FaktoryWorker.Protocol

  @faktory_version 2

  @type t :: %__MODULE__{}

  @enforce_keys [:host, :port, :socket, :socket_handler]
  defstruct [:host, :port, :socket, :socket_handler]

  @spec open(opts :: keyword()) :: {:ok, Connection.t()} | {:error, term()}
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

  @spec send_command(connection :: Connection.t(), Protocol.protocol_command()) ::
          :ok | {:error, term()}
  def send_command(%{socket_handler: socket_handler} = connection, command) do
    case Protocol.encode_command(command) do
      {:ok, payload} -> socket_handler.send(connection, payload)
      {:error, _} = error -> error
    end
  end

  @spec recv(connection :: Connection.t()) :: {:ok, term()} | {:error, term()}
  def recv(%{socket_handler: socket_handler} = connection) do
    case socket_handler.recv(connection) do
      {:ok, response} -> Protocol.decode_response(response)
      {:error, _} = error -> error
    end
  end

  defp verify_faktory_version(connection) do
    case recv(connection) do
      {:ok, response} -> verify_version(response)
      error -> error
    end
  end

  defp verify_version(%{"v" => @faktory_version}), do: :ok

  defp verify_version(%{"v" => version}) do
    {:error,
     "Only Faktory version '#{@faktory_version}' is supported (connected to Faktory version '#{
       version
     }')."}
  end

  defp verify_hello_response(connection) do
    with :ok <- send_command(connection, {:hello, @faktory_version}),
         {:ok, "OK"} <- recv(connection) do
      :ok
    end
  end
end
