defmodule FaktoryWorker do
  @moduledoc """
  TODO: docs
  """

  @doc false
  def child_spec(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)

    children = [
      {FaktoryWorker.Pool, opts},
      {FaktoryWorker.PushPipeline, opts},
      {FaktoryWorker.WorkerSupervisor, opts}
    ]

    %{
      id: opts[:name],
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end
end
