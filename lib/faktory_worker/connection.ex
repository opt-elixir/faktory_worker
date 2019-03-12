defmodule FaktoryWorker.Connection do
  @moduledoc """

  """

  alias FaktoryWorker.Socket

  @spec open(opts :: keyword()) :: {:ok, %Socket{}} | {:error, term()}
  def open(opts \\ []) do
    socket_module = Keyword.get(opts, :socket_module)
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 7419)

    with {:ok, socket} <- socket_module.connect(host, port) do
      {:ok, socket}
    end
  end
end
