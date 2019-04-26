defmodule FaktoryWorker.Socket.Tcp do
  @moduledoc false

  alias FaktoryWorker.Connection

  @behaviour FaktoryWorker.Socket

  @impl true
  def connect(host, port, _opts \\ []) do
    with {:ok, socket} <- try_connect(host, port) do
      {:ok, %Connection{host: host, port: port, socket: socket, socket_handler: __MODULE__}}
    end
  end

  @impl true
  def send(%{socket: socket}, payload) do
    :gen_tcp.send(socket, payload)
  end

  @impl true
  def recv(%{socket: socket}) do
    :gen_tcp.recv(socket, 0)
  end

  @impl true
  def recv(%{socket: socket}, length) do
    set_packet_mode(socket, :raw)
    result = :gen_tcp.recv(socket, length)
    set_packet_mode(socket, :line)

    result
  end

  defp try_connect(host, port) do
    host = String.to_charlist(host)

    :gen_tcp.connect(host, port, [:binary, active: false, packet: :line])
  end

  defp set_packet_mode(socket, mode), do: :inet.setopts(socket, packet: mode)
end
