defmodule FaktoryWorker.EventDispatcher do
  @moduledoc false

  @spec dispatch_event(event :: atom(), outcome :: term(), metadata :: map()) :: :ok
  def dispatch_event(event, outcome, metadata) do
    :telemetry.execute(
      [:faktory_worker, event],
      %{status: outcome},
      metadata
    )
  end
end
