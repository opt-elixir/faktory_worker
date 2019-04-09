defmodule FaktoryWorker.Worker.Server do
  @moduledoc false

  use GenServer

  alias FaktoryWorker.Worker

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
    Process.flag(:trap_exit, true)
    {:ok, %{}, {:continue, {:setup_connection, opts}}}
  end

  @impl true
  def handle_continue({:setup_connection, opts}, _) do
    worker = Worker.new(opts, self())
    {:noreply, worker}
  end

  @impl true
  def handle_info(:beat, state) do
    state = Worker.send_beat(state)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Worker.send_end(state)
  end

  defp name_from_opts(opts) do
    Keyword.get(opts, :name, __MODULE__)
  end
end
