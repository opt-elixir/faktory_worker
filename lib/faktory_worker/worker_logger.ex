defmodule FaktoryWorker.WorkerLogger do
  @moduledoc false

  require Logger

  @spec log_push(jid :: String.t(), args :: any()) :: :ok | {:error, any()}
  def log_push(jid, args), do: log_info("Enqueued", jid, args)

  @spec log_ack(:ok | :error, jid :: String.t(), args :: any()) :: :ok | {:error, any()}
  def log_ack(:ok, jid, args), do: log_info("Succeeded", jid, args)
  def log_ack(:error, jid, args), do: log_info("Failed", jid, args)

  @spec log_beat(:ok | :error, :ok | :error, wid :: String.t()) :: :ok | {:error, any()}
  # no state change, state == state
  def log_beat(state, state, _), do: :ok
  def log_beat(:ok, _, wid), do: log_info("Heartbeat Succeeded", wid)
  def log_beat(:error, _, wid), do: log_info("Heartbeat Failed", wid)

  @spec log_failed_ack(:ok | :error, jid :: String.t(), args :: any()) :: :ok | {:error, any()}
  def log_failed_ack(:ok, jid, args) do
    log_info("Error sending 'ACK' acknowledgement to faktory", jid, args)
  end

  @spec log_fetch(:error, jid :: String.t(), args :: any()) :: :ok | {:error, any()}
  def log_failed_ack(:error, jid, args) do
    log_info("Error sending 'FAIL' acknowledgement to faktory", jid, args)
  end

  @spec log_fetch(:error, wid :: String.t(), error :: String.t()) :: :ok | {:error, any()}
  def log_fetch(:error, wid, error) do
    log_info("Failed to fetch job due to '#{error}'", wid)
  end

  defp log_info(message) do
    Logger.info("[faktory-worker] #{message}")
  end

  defp log_info(outcome, wid) do
    log_info("#{outcome} wid-#{wid}")
  end

  defp log_info(outcome, jid, args) do
    log_info("#{outcome} jid-#{jid} #{inspect(args)}")
  end
end
