defmodule FaktoryWorker.Worker do
  @moduledoc false

  alias FaktoryWorker.ConnectionManager

  @type t :: %__MODULE__{}

  @fifteen_seconds 15_000
  @valid_beat_states [:ok, :quiet]

  defstruct [:conn, :worker_id, :worker_state, :worker_server, :beat_interval, :beat_ref]

  @spec new(opts :: keyword(), server :: pid()) :: __MODULE__.t()
  def new(opts, server) do
    worker_id = Keyword.fetch!(opts, :worker_id)
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
      worker_server: server,
      beat_interval: beat_interval
    }
    |> schedule_beat()
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

  defp handle_beat_response({{:ok, %{"state" => new_state}}, conn}, state) do
    new_state = String.to_existing_atom(new_state)
    %{state | conn: conn, worker_state: new_state}
  end

  defp handle_beat_response({_, conn}, state) do
    %{state | conn: conn}
  end

  defp clear_beat_ref(state), do: %{state | beat_ref: nil}

  defp schedule_beat(%{worker_state: worker_state} = state)
       when worker_state in @valid_beat_states do
    beat_ref = Process.send_after(state.worker_server, :beat, state.beat_interval)
    %{state | beat_ref: beat_ref}
  end

  defp schedule_beat(state), do: state
end
