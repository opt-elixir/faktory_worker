defmodule FaktoryWorker.Connection do
  @moduledoc false

  alias FaktoryWorker.Connection
  alias FaktoryWorker.Socket.{Tcp, Ssl}
  alias FaktoryWorker.Protocol

  @faktory_version 2

  @type t :: %__MODULE__{}

  @enforce_keys [:host, :port, :socket, :socket_handler]
  defstruct [:host, :port, :socket, :socket_handler]

  @spec open(opts :: keyword()) :: {:ok, Connection.t()} | {:error, term()}
  def open(opts \\ []) do
    use_tls = Keyword.get(opts, :use_tls, false)
    socket_handler = Keyword.get(opts, :socket_handler, default_socket_handler(use_tls))
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 7419)
    password = Keyword.get(opts, :password)

    with {:ok, connection} <- socket_handler.connect(host, port, opts),
         :ok <- verify_handshake(connection, password) do
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

  defp verify_handshake(connection, password) do
    connection
    |> recv()
    |> send_handshake(connection, password)
  end

  defp send_handshake({:ok, %{"v" => version}}, _, _) when version != @faktory_version do
    {:error,
     "Only Faktory version '#{@faktory_version}' is supported (connected to Faktory version '#{
       version
     }')."}
  end

  defp send_handshake({:ok, response}, connection, password) do
    args =
      %{v: @faktory_version}
      |> append_password_hash(response, password)

    with :ok <- send_command(connection, {:hello, args}),
         {:ok, "OK"} <- recv(connection) do
      :ok
    end
  end

  defp send_handshake({:error, _} = error, _, _), do: error

  defp append_password_hash(args, %{"i" => iterations, "s" => salt}, password) do
    hash =
      1..iterations
      |> Enum.reduce("#{password}#{salt}", fn _, acc ->
        :crypto.hash(:sha256, acc)
      end)
      |> Base.encode16(case: :lower)

    Map.put(args, :pwdhash, hash)
  end

  defp append_password_hash(args, _, _), do: args

  defp default_socket_handler(true), do: Ssl
  defp default_socket_handler(_), do: Tcp
end
