defmodule FaktoryWorker.PushPipeline.Consumer do
  @moduledoc false

  alias FaktoryWorker.Job

  @behaviour Broadway

  @impl true
  def handle_message(_processor_name, message, _context), do: message

  @impl true
  def handle_batch(_, [%{data: {_, job}} = message], _batch_info, %{name: name}) do
    result =
      case Job.push(name, job) do
        {:ok, _} -> :ok
        error -> error
      end

    [%{message | status: result}]
  end
end
