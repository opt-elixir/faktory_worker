defmodule FaktoryWorker.Random do
  @moduledoc false

  def job_id() do
    random_hex(12)
  end

  def worker_id() do
    random_hex(8)
  end

  def string() do
    random_hex(16)
  end

  defp random_hex(byte_length) do
    byte_length
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end
end
