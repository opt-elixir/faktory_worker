defmodule FaktoryWorker.PushPipeline.Producer do
  @moduledoc false

  use GenStage

  def init(_opts) do
    {:producer, %{jobs: []}}
  end

  def handle_demand(demand, %{jobs: jobs} = state) do
    {dispatch_jobs, remaing_jobs} = Enum.split(jobs, demand)

    {:noreply, dispatch_jobs, %{state | jobs: remaing_jobs}}
  end
end
