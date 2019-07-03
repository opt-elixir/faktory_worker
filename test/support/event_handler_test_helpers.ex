defmodule FaktoryWorker.EventHandlerTestHelpers do
  @moduledoc false

  alias FaktoryWorker.Random

  defmacro attach_event_handler(events) do
    quote do
      handler_id = Random.string()
      test_events = Enum.map(unquote(events), &[:faktory_worker, &1])

      :telemetry.attach_many(
        handler_id,
        test_events,
        &FaktoryWorker.EventHandlerTestHelpers.handle_event/4,
        []
      )

      handler_id
    end
  end

  defmacro detach_event_handler(handler_id) do
    quote do
      :ok = :telemetry.detach(unquote(handler_id))
    end
  end

  @doc false
  def handle_event(event, measurements, metadata, _config) do
    Process.send(self(), {event, measurements, metadata}, [])
  end
end
