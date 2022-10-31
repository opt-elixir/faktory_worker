defmodule FaktoryWorker.ConnectionManager do
  @moduledoc false

  alias FaktoryWorker.Connection
  alias FaktoryWorker.ConnectionManager

  require Logger

  @type t :: %__MODULE__{}

  @connection_errors [
    :closed,
    :enotconn,
    :econnrefused
  ]

  defstruct [:opts, :conn]

  @spec new(opts :: keyword()) :: ConnectionManager.t()
  def new(opts) do
    %__MODULE__{
      conn: open_connection(opts),
      opts: opts
    }
  end

  @spec send_command(
          state :: ConnectionManager.t(),
          command :: FaktoryWorker.Protocol.protocol_command(),
          allow_retry :: boolean()
        ) ::
          {Connection.response(), ConnectionManager.t()}
  def send_command(state, command, allow_retry \\ true) do
    case try_send_command(state, command) do
      {{:error, reason}, _} when reason in @connection_errors ->
        # Close dangling port
        close_connection(state)
        error = {:error, "Failed to connect to Faktory"}
        state = %{state | conn: nil}

        if allow_retry,
          do: send_command(%{state | conn: nil}, command, false),
          else: {error, state}

      # Handle errors from Faktory that should not be tried again
      {{:error, "Halt: " <> reason = error}, state} ->
        log_error(error, command)

        {{:ok, reason}, state}

      {{:ok, :closed}, state} ->
        {{:ok, :closed}, %{state | conn: nil}}

      result ->
        result
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
      {:error, _reason} -> nil
    end
  end

  defp close_connection(%{conn: conn}) do
    Connection.close(conn)
  end

  defp log_error(reason, {_, %{jid: jid}}) do
    Logger.warn("[#{jid}] #{reason}")
  end
end
