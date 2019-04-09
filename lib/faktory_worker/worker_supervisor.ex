defmodule FaktoryWorker.WorkerSupervisor do
  @moduledoc false

  use Supervisor

  alias FaktoryWorker.Random

  @spec start_link(opts :: keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name)
    Supervisor.start_link(__MODULE__, opts, name: :"#{name}_worker_supervisor")
  end

  @impl true
  def init(opts) do
    children =
      opts
      |> Keyword.get(:workers, [])
      |> Enum.map(&map_worker/1)
      |> List.flatten()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp map_worker(worker_module) do
    worker_opts = worker_module.worker_config()
    concurrency = Keyword.get(worker_opts, :concurrency, 1)

    Enum.reduce(1..concurrency, [], fn _, acc ->
      worker_id = Random.worker_id()
      worker_name = :"#{worker_module}_#{worker_id}"

      opts = [name: worker_name, worker_id: worker_id, worker_module: worker_module]

      [FaktoryWorker.Worker.Server.child_spec(opts) | acc]
    end)
  end
end
