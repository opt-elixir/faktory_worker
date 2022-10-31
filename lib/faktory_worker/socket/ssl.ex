defmodule FaktoryWorker.Socket.Ssl do
  @moduledoc false

  alias FaktoryWorker.Connection

  @behaviour FaktoryWorker.Socket

  @impl true
  def connect(host, port, opts \\ []) do
    with {:ok, socket} <- try_connect(host, port, opts) do
      {:ok, %Connection{host: host, port: port, socket: socket, socket_handler: __MODULE__}}
    end
  end

  @impl true
  def send(%{socket: socket}, payload) do
    :ssl.send(socket, payload)
  end

  @impl true
  def recv(%{socket: socket}) do
    :ssl.recv(socket, 0)
  end

  @impl true
  def recv(%{socket: socket}, length) do
    set_packet_mode(socket, :raw)
    result = :ssl.recv(socket, length)
    set_packet_mode(socket, :line)

    result
  end

  @impl true
  def close(%{socket: socket}) do
    :ssl.close(socket)
  end

  defp try_connect(host, port, opts) do
    host = String.to_charlist(host)
    tls_verify = Keyword.get(opts, :tls_verify, true)

    opts = [
      :binary,
      active: false,
      packet: :line,
      depth: 2,
      versions: [:"tlsv1.2"],
      verify: map_tls_verify(tls_verify),
      cacerts: :certifi.cacerts()
    ]

    :ssl.connect(host, port, opts)
  end

  defp map_tls_verify(true), do: :verify_peer
  defp map_tls_verify(_), do: :verify_none

  defp set_packet_mode(socket, mode), do: :ssl.setopts(socket, packet: mode)
end
