defmodule FaktoryWorker.QueueManager do
  @moduledoc false

  use Agent

  defmodule Queue do
    @enforce_keys [:name, :concurrency]
    defstruct [:name, :concurrency]
  end

  def start_link(opts) do
    name = opts[:name]
    pool_opts = Keyword.get(opts, :worker_pool, [])
    queues = Keyword.get(pool_opts, :queues, ["default"])
    state = Enum.map(queues, &map_queues/1)

    Agent.start_link(fn -> state end, name: format_queue_manager_name(name))
  end

  @spec checkout_queues(queue_manager_name :: atom()) :: list(String.t())
  def checkout_queues(queue_manager_name) do
    Agent.get_and_update(queue_manager_name, fn queues ->
      queues
      |> Enum.map_reduce([], &map_queue_to_fetch/2)
      |> format_queues_to_fetch()
    end)
  end

  @spec checkin_queues(queue_manager_name :: atom(), queues :: list(String.t())) :: :ok
  def checkin_queues(queue_manager_name, queues) do
    Agent.cast(queue_manager_name, fn state_queues ->
      Enum.map(state_queues, &update_checkin_queues(&1, queues))
    end)

    :ok
  end

  @spec format_queue_manager_name(name :: atom()) :: atom()
  def format_queue_manager_name(name) when is_atom(name) do
    :"#{name}_queue_manager"
  end

  defp map_queues(queue) when is_binary(queue) do
    %Queue{name: queue, concurrency: :infinity}
  end

  defp map_queues({queue, opts}) when is_binary(queue) do
    concurrency = Keyword.get(opts, :concurrency, :infinity)
    %Queue{name: queue, concurrency: concurrency}
  end

  defp map_queue_to_fetch(%{concurrency: :infinity} = queue, acc) do
    {queue.name, [queue | acc]}
  end

  defp map_queue_to_fetch(%{concurrency: 0} = queue, acc) do
    {nil, [queue | acc]}
  end

  defp map_queue_to_fetch(%{concurrency: concurrency} = queue, acc) when concurrency > 0 do
    queue = %{queue | concurrency: concurrency - 1}
    {queue.name, [queue | acc]}
  end

  defp update_checkin_queues(%{concurrency: :infinity} = queue, _), do: queue

  defp update_checkin_queues(queue, checkin_queues) do
    if Enum.member?(checkin_queues, queue.name) do
      %{queue | concurrency: queue.concurrency + 1}
    else
      queue
    end
  end

  defp format_queues_to_fetch({queues, state}) do
    queues = Enum.reject(queues, &is_nil/1)
    state = Enum.reverse(state)
    {queues, state}
  end
end
