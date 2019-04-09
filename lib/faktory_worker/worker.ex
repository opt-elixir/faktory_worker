defmodule FaktoryWorker.Worker do
  @moduledoc false

  alias FaktoryWorker.ConnectionManager

  @type t :: %__MODULE__{}

  @two_seconds 2000
  @fifteen_seconds 15_000
  @valid_beat_states [:ok, :quiet, :running_job]

  defstruct [
    :conn,
    :worker_id,
    :worker_state,
    :worker_server,
    :worker_config,
    :fetch_interval,
    :fetch_ref,
    :beat_interval,
    :beat_ref
  ]

  @spec new(opts :: keyword()) :: __MODULE__.t()
  def new(opts) do
    worker_id = Keyword.fetch!(opts, :worker_id)
    worker_module = Keyword.fetch!(opts, :worker_module)
    fetch_interval = Keyword.get(opts, :fetch_interval, @two_seconds)
    beat_interval = Keyword.get(opts, :beat_interval, @fifteen_seconds)

    connection =
      opts
      |> Keyword.get(:connection, [])
      |> Keyword.put(:is_worker, true)
      |> Keyword.put(:worker_id, worker_id)
      |> ConnectionManager.new()

    %__MODULE__{
      conn: connection,
      worker_id: worker_id,
      worker_state: :ok,
      worker_config: worker_module.worker_config(),
      fetch_interval: fetch_interval,
      beat_interval: beat_interval
    }
    |> schedule_beat()
    |> schedule_fetch()
  end

  @spec send_end(state :: __MODULE__.t()) :: __MODULE__.t()
  def send_end(%{conn: conn} = state) do
    conn
    |> ConnectionManager.send_command(:end)
    |> handle_end_response(state)
  end

  @spec send_beat(state :: __MODULE__.t()) :: __MODULE__.t()
  def send_beat(%{worker_state: worker_state} = state)
      when worker_state in @valid_beat_states do
    state.conn
    |> ConnectionManager.send_command({:beat, state.worker_id})
    |> handle_beat_response(state)
    |> clear_beat_ref()
    |> schedule_beat()
  end

  def send_beat(state), do: clear_beat_ref(state)

  def send_fetch(%{worker_state: worker_state} = state) when worker_state == :ok do
    queues =
      state.worker_config
      |> Keyword.get(:queue, [])
      |> format_queue_for_command()

    state.conn
    |> ConnectionManager.send_command({:fetch, queues})
    |> handle_fetch_response(state)
    |> schedule_fetch()
  end

  def send_fetch(state), do: clear_fetch_ref(state)

  defp handle_beat_response({{:ok, %{"state" => new_state}}, conn}, state) do
    new_state = String.to_existing_atom(new_state)
    %{state | conn: conn, worker_state: new_state}
  end

  defp handle_beat_response({_, conn}, state) do
    %{state | conn: conn}
  end

  defp handle_end_response({_, conn}, state) do
    %{conn: nil} = ConnectionManager.close_connection(conn)
    %{state | worker_state: :ended, conn: nil}
  end

  defp clear_beat_ref(state), do: %{state | beat_ref: nil}

  defp schedule_beat(%{worker_state: worker_state} = state)
       when worker_state in @valid_beat_states do
    beat_ref = Process.send_after(self(), :beat, state.beat_interval)
    %{state | beat_ref: beat_ref}
  end

  defp schedule_beat(state), do: state

  defp handle_fetch_response({{:ok, :no_content}, conn}, state) do
    %{state | conn: conn}
  end

  defp handle_fetch_response({{_, r}, conn}, state) do
    IO.inspect(r)
    %{state | conn: conn, worker_state: :running_job}
  end

  defp clear_fetch_ref(state), do: %{state | fetch_ref: nil}

  defp schedule_fetch(%{worker_state: worker_state} = state) when worker_state == :ok do
    fetch_ref = Process.send_after(self(), :fetch, state.fetch_interval)
    %{state | fetch_ref: fetch_ref}
  end

  defp schedule_fetch(state), do: state

  defp format_queue_for_command(queue) when is_binary(queue), do: [queue]
  defp format_queue_for_command(queues), do: queues
end
