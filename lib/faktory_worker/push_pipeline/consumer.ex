defmodule FaktoryWorker.PushPipeline.Consumer do
  @moduledoc false

  alias FaktoryWorker.WorkerLogger
  alias FaktoryWorker.{ConnectionManager, Pool}

  @behaviour Broadway

  @default_timeout 5000

  @impl true
  def handle_message(_processor_name, message, _context), do: message

  @impl true
  def handle_batch(_, [%{data: {_, job}} = message], _batch_info, %{name: name}) do
    result =
      name
      |> Pool.format_pool_name()
      |> :poolboy.transaction(
        &ConnectionManager.Server.send_command(&1, {:push, job}),
        @default_timeout
      )
      |> send_command_result(job)

    [%{message | status: result}]
  end

  defp send_command_result({:ok, _}, job) do
    WorkerLogger.log_push(job.jid, job.args)
    :ok
  end

  defp send_command_result({:error, reason}, _), do: {:failed, reason}
end
