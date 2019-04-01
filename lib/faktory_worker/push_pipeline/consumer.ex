defmodule FaktoryWorker.PushPipeline.Consumer do
  @moduledoc false

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
      |> send_command_result()

    [%{message | status: result}]
  end

  defp send_command_result({:ok, _}), do: :ok
  defp send_command_result({:error, reason}), do: {:failed, reason}
end
