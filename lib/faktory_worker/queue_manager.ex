defmodule FaktoryWorker.QueueManager do
  @moduledoc false

  use Agent

  defmodule Queue do
    @moduledoc false

    @enforce_keys [:name, :max_concurrency]
    defstruct [:name, :max_concurrency]
  end

  def start_link(opts) do
    name = opts[:name]
    pool_opts = Keyword.get(opts, :worker_pool, [])
    pool_size = Keyword.get(pool_opts, :size, 10)
    queues = Keyword.get(pool_opts, :queues, ["default"])

    queues = Enum.map(queues, fn queue -> map_queues(queue, pool_size) end)
    concurrency_per_worker = calc_concurrency_per_worker(pool_size, queues)

    Agent.start_link(fn -> {concurrency_per_worker, queues} end,
      name: format_queue_manager_name(name)
    )
  end

  @spec checkout_queues(queue_manager_name :: atom()) :: list(String.t())
  def checkout_queues(queue_manager_name) do
    Agent.get_and_update(queue_manager_name, fn {concurrency_per_worker, queues} ->
      sorted_by_concurrency = Enum.sort_by(queues, & &1.max_concurrency, :desc)

      {resp, state} =
        sorted_by_concurrency
        |> Enum.take(concurrency_per_worker)
        |> Enum.map_reduce([], &map_queue_to_fetch/2)
        |> format_queues_to_fetch()

      state_queues =
        sorted_by_concurrency
        |> Enum.drop(concurrency_per_worker)
        |> Enum.concat(state)

      {resp, {concurrency_per_worker, state_queues}}
    end)
  end

  @spec checkin_queues(queue_manager_name :: atom(), queues :: list(String.t())) :: :ok
  def checkin_queues(queue_manager_name, queues) do
    Agent.cast(queue_manager_name, fn {concurrency_per_worker, state_queues} ->
      {concurrency_per_worker, Enum.map(state_queues, &update_checkin_queues(&1, queues))}
    end)

    :ok
  end

  @spec format_queue_manager_name(name :: atom()) :: atom()
  def format_queue_manager_name(name) when is_atom(name) do
    :"#{name}_queue_manager"
  end

  defp map_queues(queue, pool_size) when is_binary(queue) do
    %Queue{name: queue, max_concurrency: pool_size}
  end

  defp map_queues({queue, opts}, pool_size) when is_binary(queue) do
    max_concurrency = Keyword.get(opts, :max_concurrency, pool_size)
    %Queue{name: queue, max_concurrency: max_concurrency}
  end

  defp map_queue_to_fetch(%{max_concurrency: 0} = queue, acc) do
    {nil, [queue | acc]}
  end

  defp map_queue_to_fetch(%{max_concurrency: max_concurrency} = queue, acc)
       when max_concurrency > 0 do
    queue = %{queue | max_concurrency: max_concurrency - 1}
    {queue.name, [queue | acc]}
  end

  defp update_checkin_queues(queue, checkin_queues) do
    if Enum.member?(checkin_queues, queue.name) do
      %{queue | max_concurrency: queue.max_concurrency + 1}
    else
      queue
    end
  end

  defp format_queues_to_fetch({queues, state}) do
    queues = Enum.reject(queues, &is_nil/1)
    state = Enum.reverse(state)
    {queues, state}
  end

  defp calc_concurrency_per_worker(pool_size, queues) do
    sum_max_concurrency = queues |> Enum.map(& &1.max_concurrency) |> Enum.sum()
    ceil(sum_max_concurrency / pool_size)
  end
end
