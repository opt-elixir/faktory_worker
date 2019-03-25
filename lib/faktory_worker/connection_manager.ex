defmodule FaktoryWorker.ConnectionManager do
  @moduledoc false

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    {:ok, connection} = FaktoryWorker.Connection.open(opts)
    {:ok, %{conn: connection}}
  end
end
