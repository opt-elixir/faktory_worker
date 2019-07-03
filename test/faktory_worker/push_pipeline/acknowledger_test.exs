defmodule FaktoryWorker.PushPipeline.AcknowledgerTest do
  use ExUnit.Case

  import FaktoryWorker.EventHandlerTestHelpers

  alias FaktoryWorker.Random
  alias FaktoryWorker.PushPipeline.Acknowledger

  describe "ack/3" do
    test "should dispatch the job not unique event" do
      event_handler_id = attach_event_handler([:push])

      jid = Random.job_id()

      payload = %{
        jid: jid,
        args: ["some args"],
        jobtype: "TestWorker"
      }

      failed_message = %{
        status: {:error, :not_unique},
        data: {nil, payload}
      }

      :ok = Acknowledger.ack(nil, [], [failed_message])

      assert_receive {[:faktory_worker, :push], outcome, metadata}
      assert outcome == %{status: {:error, :not_unique}}

      assert metadata == payload

      detach_event_handler(event_handler_id)
    end
  end
end
