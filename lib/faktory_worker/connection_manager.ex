defmodule FaktoryWorker.ConnectionManager do
  @moduledoc false

  alias FaktoryWorker.Connection
  alias FaktoryWorker.ConnectionManager

  @connection_errors [
    :closed,
    :enotconn,
    :econnrefused
  ]

  defstruct [:opts, :conn]

  def new(opts) do
    %__MODULE__{
      conn: open_connection(opts),
      opts: opts
    }
  end

  def send_command(%ConnectionManager{} = state, command) do
    case try_send_command(state, command) do
      {{:error, reason}, _} when reason in @connection_errors ->
        error = {:error, "Failed to connect to Faktory"}
        state = %{state | conn: nil}

        {error, state}

      {result, state} ->
        {result, state}
    end
  end

  defp try_send_command(%{conn: nil, opts: opts} = state, command) do
    case open_connection(opts) do
      nil ->
        {{:error, "Failed to connect to Faktory"}, state}

      connection ->
        state = %{state | conn: connection}

        try_send_command(state, command)
    end
  end

  defp try_send_command(%{conn: connection} = state, command) do
    result = Connection.send_command(connection, command)
    {result, state}
  end

  defp open_connection(opts) do
    case Connection.open(opts) do
      {:ok, connection} -> connection
      _ -> nil
    end
  end
end
