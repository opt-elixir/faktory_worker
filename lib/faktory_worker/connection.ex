defmodule FaktoryWorker.Connection do
  @moduledoc false

  alias FaktoryWorker.Socket.{Tcp, Ssl}
  alias FaktoryWorker.Protocol

  @faktory_version 2

  @type t :: %__MODULE__{}

  @type response :: Protocol.protocol_response() | {:ok, :closed}

  @enforce_keys [:host, :port, :socket, :socket_handler]
  defstruct [:host, :port, :socket, :socket_handler]

  @spec open(opts :: keyword()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def open(opts \\ []) do
    use_tls = Keyword.get(opts, :use_tls, false)
    socket_handler = Keyword.get(opts, :socket_handler, default_socket_handler(use_tls))
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 7419)

    with {:ok, connection} <- socket_handler.connect(host, port, opts),
         {:ok, _} <- verify_handshake(connection, opts) do
      {:ok, connection}
    end
  end

  @spec close(conn :: __MODULE__.t()) :: :ok
  def close(%{socket_handler: socket_handler} = conn) do
    socket_handler.close(conn)
  end

  @spec send_command(connection :: __MODULE__.t(), Protocol.protocol_command()) :: response()
  def send_command(%{socket_handler: socket_handler} = connection, :end) do
    with {:ok, payload} <- Protocol.encode_command(:end),
         :ok <- socket_handler.send(connection, payload) do
      {:ok, :closed}
    end
  end

  def send_command(%{socket_handler: socket_handler} = connection, command) do
    with {:ok, payload} <- Protocol.encode_command(command),
         :ok <- socket_handler.send(connection, payload),
         {:ok, _} = response <- recv(connection) do
      response
    end
  end

  defp recv(%{socket_handler: socket_handler} = connection) do
    connection
    |> socket_handler.recv()
    |> decode_response(connection)
  end

  defp recv(%{socket_handler: socket_handler} = connection, length) do
    connection
    |> socket_handler.recv(length)
    |> decode_response(connection)
  end

  defp decode_response({:ok, response}, connection) do
    case Protocol.decode_response(response) do
      {:ok, {:bulk_string, len}} ->
        recv(connection, len)

      result ->
        result
    end
  end

  defp decode_response({:error, _} = error, _), do: error

  defp verify_handshake(connection, opts) do
    connection
    |> recv()
    |> send_handshake(connection, opts)
  end

  defp send_handshake({:ok, %{"v" => version}}, _, _) when version != @faktory_version do
    {:error,
     "Only Faktory version '#{@faktory_version}' is supported (connected to Faktory version '#{version}')."}
  end

  defp send_handshake({:ok, response}, connection, opts) do
    password = Keyword.get(opts, :password)

    args =
      %{v: @faktory_version}
      |> append_password_hash(response, password)
      |> append_worker_fields(opts)

    send_command(connection, {:hello, args})
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

  defp append_worker_fields(args, opts) do
    is_worker = Keyword.get(opts, :is_worker, false)

    if is_worker,
      do: put_worker_args(args, opts),
      else: args
  end

  defp put_worker_args(args, opts) do
    process_wid = Keyword.get(opts, :process_wid)
    sys_pid = System.pid()
    {:ok, hostname} = :inet.gethostname()

    worker_args = %{
      hostname: to_string(hostname),
      wid: process_wid,
      pid: String.to_integer(sys_pid),
      labels: ["elixir-#{System.version()}"]
    }

    Map.merge(args, worker_args)
  end

  defp default_socket_handler(true), do: Ssl
  defp default_socket_handler(_), do: Tcp
end
