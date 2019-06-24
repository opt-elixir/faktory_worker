defmodule FaktoryWorker.PushPipeline.AcknowledgerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias FaktoryWorker.Random
  alias FaktoryWorker.PushPipeline.Acknowledger

  describe "ack/3" do
    test "should log the not unique log message" do
      jid = Random.job_id()

      payload = %{
        jid: jid,
        args: ["some args"],
        jobtype: "TestWorker"
      }

      failed_message = %{
        status: {:failed, :not_unique},
        data: {nil, payload}
      }

      log =
        capture_log(fn ->
          :ok = Acknowledger.ack(nil, [], [failed_message])
        end)

      assert log =~ "NOTUNIQUE (TestWorker) jid-#{jid} #{inspect(payload.args)}"
    end
  end
end
