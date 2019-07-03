defmodule FaktoryWorker.EventDispatcherTest do
  use ExUnit.Case

  import FaktoryWorker.EventHandlerTestHelpers

  alias FaktoryWorker.EventDispatcher

  describe "dispatch_event/3" do
    test "should dispatch an event" do
      event_handler_id = attach_event_handler([:test_event])

      EventDispatcher.dispatch_event(:test_event, "test outcome", %{metadata: "test"})

      assert_receive {event, outcome, metadata}
      assert event == [:faktory_worker, :test_event]
      assert outcome == %{status: "test outcome"}
      assert metadata == %{metadata: "test"}

      detach_event_handler(event_handler_id)
    end
  end
end
