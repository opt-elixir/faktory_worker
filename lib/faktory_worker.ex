defmodule FaktoryWorker do
  @moduledoc """
  TODO: docs
  """

  @doc false
  def child_spec(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    opts = Keyword.put(opts, :name, name)

    children = [
      {FaktoryWorker.Pool, opts},
      {FaktoryWorker.PushPipeline, opts}
    ]

    %{
      id: name,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end
end
