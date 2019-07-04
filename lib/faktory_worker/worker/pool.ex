defmodule FaktoryWorker.Worker.Pool do
  @moduledoc false

  use Supervisor

  @spec start_link(opts :: keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: format_worker_pool_name(opts))
  end

  @impl true
  def init(opts) do
    pool_opts = Keyword.get(opts, :worker_pool, [])
    size = Keyword.get(pool_opts, :size, 10)

    children = Enum.map(1..size, fn i -> map_connection(i, opts) end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp map_connection(number, opts) do
    connection_opts = Keyword.get(opts, :connection, [])
    process_wid = Keyword.get(opts, :process_wid)
    pool_opts = Keyword.get(opts, :worker_pool, [])
    disable_fetch = Keyword.get(pool_opts, :disable_fetch, false)

    opts = [
      name: :"worker_#{process_wid}_#{number}",
      faktory_name: Keyword.get(opts, :name),
      connection: connection_opts,
      process_wid: process_wid,
      disable_fetch: disable_fetch
    ]

    FaktoryWorker.Worker.Server.child_spec(opts)
  end

  def format_worker_pool_name(opts) do
    name = Keyword.get(opts, :name)
    :"#{name}_worker_pool"
  end
end
