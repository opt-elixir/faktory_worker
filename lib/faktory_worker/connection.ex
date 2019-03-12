defmodule FaktoryWorker.Connection do
  @moduledoc """

  """

  alias FaktoryWorker.Socket
  alias FaktoryWorker.Socket.Tcp

  @spec open(opts :: keyword()) :: {:ok, %Socket{}} | {:error, term()}
  def open(opts \\ []) do
    socket_module = Keyword.get(opts, :socket_module, Tcp)
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 7419)

    with {:ok, socket} <- socket_module.connect(host, port) do
      {:ok, socket}
    end
  end
end
