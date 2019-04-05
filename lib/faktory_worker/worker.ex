defmodule FaktoryWorker.Worker do
  @moduledoc false

  use GenServer

  alias FaktoryWorker.ConnectionManager

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: name_from_opts(opts))
  end

  @spec child_spec(opts :: keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: name_from_opts(opts),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  @impl true
  def init(opts) do
    state = %{opts: opts, conn: nil}

    {:ok, state, {:continue, :setup_connection}}
  end

  @impl true
  def handle_continue(:setup_connection, %{opts: opts} = state) do
    worker_id = Keyword.get(opts, :worker_id)

    connection =
      opts
      |> Keyword.get(:connection, [])
      |> Keyword.put(:is_worker, true)
      |> Keyword.put(:worker_id, worker_id)
      |> ConnectionManager.new()

    {:noreply, %{state | conn: connection}}
  end

  defp name_from_opts(opts) do
    Keyword.get(opts, :name, __MODULE__)
  end
end
