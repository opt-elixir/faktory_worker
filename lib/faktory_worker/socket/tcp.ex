defmodule FaktoryWorker.Socket.Tcp do
  @moduledoc false

  alias FaktoryWorker.Socket

  @behaviour Socket

  @impl true
  def connect(host, port) do
    with {:ok, socket} <- try_connect(host, port) do
      {:ok, %Socket{host: host, port: port, socket: socket}}
    end
  end

  defp try_connect(host, port) do
    host = String.to_charlist(host)

    :gen_tcp.connect(host, port, [:binary, active: false, packet: :line])
  end
end
