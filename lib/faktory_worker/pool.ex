defmodule FaktoryWorker.Pool do
  @moduledoc false

  def child_spec(opts) do
    name = opts[:name]
    pool_name = :"#{name}_pool"
    pool_config = Keyword.get(opts, :pool, [])

    :poolboy.child_spec(
      pool_name,
      [
        {:name, {:local, pool_name}},
        {:worker_module, FaktoryWorker.ConnectionManager},
        {:size, Keyword.get(pool_config, :size, 10)},
        {:max_overflow, Keyword.get(pool_config, :size, 10)}
      ],
      Keyword.get(opts, :connection, [])
    )
  end
end
