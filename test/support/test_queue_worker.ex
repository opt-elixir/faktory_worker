defmodule FaktoryWorker.TestQueueWorker do
  @moduledoc false
  use FaktoryWorker.Job, queue: "test_queue"

  def perform(args) do
    send_to_process(args["_send_to_"], args)
  end

  defp send_to_process("#PID" <> pid_string, args) do
    pid =
      pid_string
      |> :erlang.binary_to_list()
      |> :erlang.list_to_pid()

    send(pid, {__MODULE__, :perform, args})
    :ok
  end

  defp send_to_process(_, _), do: :ok
end
