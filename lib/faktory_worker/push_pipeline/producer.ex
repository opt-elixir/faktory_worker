defmodule FaktoryWorker.PushPipeline.Producer do
  @moduledoc false

  use GenStage

  @impl true
  def init(opts) do
    buffer_size = Keyword.get(opts, :buffer_size, :infinity)

    {:producer, %{jobs: []}, buffer_size: buffer_size}
  end

  @impl true
  def handle_demand(demand, %{jobs: jobs} = state) do
    {dispatch_jobs, remaing_jobs} = Enum.split(jobs, demand)

    {:noreply, dispatch_jobs, %{state | jobs: remaing_jobs}}
  end
end
