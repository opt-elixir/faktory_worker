defmodule FaktoryWorker.PushPipeline.Consumer do
  @moduledoc false

  alias FaktoryWorker.Telemetry
  alias FaktoryWorker.{ConnectionManager, Pool}

  @behaviour Broadway

  @default_timeout 5000

  @impl true
  def handle_message(_processor_name, message, _context), do: message

  @impl true
  def handle_batch(_, [%{data: {_, job, command}} = message], _batch_info, %{name: name}) do
    result =
      name
      |> Pool.format_pool_name()
      |> :poolboy.transaction(
        &ConnectionManager.Server.send_command(&1, {command, job}),
        @default_timeout
      )
      |> send_command_result(job, command)

    [%{message | status: result}]
  end

  defp send_command_result({:ok, _}, job, command) do
    Telemetry.execute(command, :ok, job)
  end

  defp send_command_result({:error, reason}, _, _), do: {:error, reason}
end
