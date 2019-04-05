defmodule FaktoryWorker.Worker do
  @moduledoc false

  use GenServer

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
  def init(_opts) do
    {:ok, []}
  end

  defp name_from_opts(opts) do
    Keyword.get(opts, :name, __MODULE__)
  end
end
