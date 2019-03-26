defmodule FaktoryWorker.PushPipeline.Consumer do
  @moduledoc false

  alias FaktoryWorker.{ConnectionManager, Pool}

  @behaviour Broadway

  @impl true
  def handle_message(_processor_name, message, _context), do: message

  @impl true
  def handle_batch(_, [%{data: job} = message], _batch_info, %{name: name}) do
    result =
      name
      |> Pool.format_pool_name()
      |> :poolboy.transaction(
        &ConnectionManager.send_command(&1, {:push, job}),
        5000
      )
      |> send_command_result()

    [%{message | status: result}]
  end

  defp send_command_result({:ok, _}), do: :ok
  defp send_command_result({:error, reason}), do: {:failed, reason}
end
