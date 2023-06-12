defmodule FaktoryWorker.TelemetryTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import FaktoryWorker.EventHandlerTestHelpers

  alias FaktoryWorker.Random
  alias FaktoryWorker.Telemetry

  describe "attach_default_handler/0" do
    test "should attach the default FaktoryWorker telemetry handler" do
      Telemetry.attach_default_handler()

      event_handlers = :telemetry.list_handlers([:faktory_worker])

      [handler_name] =
        event_handlers
        |> Enum.filter(&(&1.id == :faktory_worker_logger))
        |> Enum.map(& &1.id)
        |> Enum.uniq()

      [handler_function] =
        event_handlers
        |> Enum.filter(&(&1.id == :faktory_worker_logger))
        |> Enum.map(& &1.function)
        |> Enum.uniq()

      handled_events = Enum.map(event_handlers, & &1.event_name)

      assert handler_name == :faktory_worker_logger
      assert handler_function == (&FaktoryWorker.Telemetry.handle_event/4)
      assert Enum.member?(handled_events, [:faktory_worker, :push])
      assert Enum.member?(handled_events, [:faktory_worker, :beat])
      assert Enum.member?(handled_events, [:faktory_worker, :fetch])
      assert Enum.member?(handled_events, [:faktory_worker, :ack])
      assert Enum.member?(handled_events, [:faktory_worker, :failed_ack])

      detach_event_handler(:faktory_worker_logger)
    end
  end

  describe "execute/3" do
    test "should execute an event to telemetry" do
      event_handler_id = attach_event_handler([:test_event])

      Telemetry.execute(:test_event, "test outcome", %{metadata: "test"})

      assert_receive {event, outcome, metadata}
      assert event == [:faktory_worker, :test_event]
      assert outcome == %{status: "test outcome"}
      assert metadata == %{metadata: "test"}

      detach_event_handler(event_handler_id)
    end
  end

  describe "handle_event/4" do
    test "should log a successful push event" do
      outcome = %{status: :ok}

      metadata = %{
        jid: Random.job_id(),
        args: %{hey: "there!"},
        jobtype: "TestQueueWorker"
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :push], outcome, metadata, [])
        end)

      assert log_message =~
               "[faktory-worker] Enqueued (#{metadata.jobtype}) jid-#{metadata.jid} #{
                 inspect(metadata.args)
               }"
    end

    test "should log a not unique job event" do
      outcome = %{status: {:error, :not_unique}}

      metadata = %{
        jid: Random.job_id(),
        args: %{hey: "there!"},
        jobtype: "TestQueueWorker"
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :push], outcome, metadata, [])
        end)

      assert log_message =~
               "[faktory-worker] NOTUNIQUE (#{metadata.jobtype}) jid-#{metadata.jid} #{
                 inspect(metadata.args)
               }"
    end

    test "should log a successful beat when the previous beat failed" do
      outcome = %{status: :ok}

      metadata = %{
        prev_status: :error,
        wid: Random.process_wid()
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :beat], outcome, metadata, [])
        end)

      assert log_message =~ "[faktory-worker] Heartbeat Succeeded wid-#{metadata.wid}"
    end

    test "should log a failed beat event when the previous beat was successful" do
      outcome = %{status: :error}

      metadata = %{
        prev_status: :ok,
        wid: Random.process_wid()
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :beat], outcome, metadata, [])
        end)

      assert log_message =~ "[faktory-worker] Heartbeat Failed wid-#{metadata.wid}"
    end

    test "should not log a beat event when the outcome didn't change" do
      outcome = %{status: :ok}

      metadata = %{
        prev_status: :ok,
        wid: Random.process_wid()
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :beat], outcome, metadata, [])
        end)

      assert log_message == ""
    end

    test "should log a failed fetch event" do
      outcome = %{status: {:error, "Shutdown in progress"}}

      metadata = %{
        wid: Random.process_wid()
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :fetch], outcome, metadata, [])
        end)

      assert log_message =~
               "[faktory-worker] Failed to fetch job due to 'Shutdown in progress' wid-#{
                 metadata.wid
               }"
    end

    test "should log a successful job ack event" do
      outcome = %{status: :ok}

      metadata = %{
        jid: Random.job_id(),
        args: %{hey: "there!"},
        jobtype: "TestQueueWorker"
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :ack], outcome, metadata, [])
        end)

      assert log_message =~
               "[faktory-worker] Succeeded (#{metadata.jobtype}) jid-#{metadata.jid} #{
                 inspect(metadata.args)
               }"
    end

    test "should log a failed job ack event" do
      outcome = %{status: :error}

      metadata = %{
        jid: Random.job_id(),
        args: %{hey: "there!"},
        jobtype: "TestQueueWorker"
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :ack], outcome, metadata, [])
        end)

      assert log_message =~
               "[faktory-worker] Failed (#{metadata.jobtype}) jid-#{metadata.jid} #{
                 inspect(metadata.args)
               }"
    end

    test "should log a failed 'ACK' ack event" do
      outcome = %{status: :ok}

      metadata = %{
        jid: Random.job_id(),
        args: %{hey: "there!"},
        jobtype: "TestQueueWorker"
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :failed_ack], outcome, metadata, [])
        end)

      assert log_message =~
               "[faktory-worker] Error sending 'ACK' acknowledgement to faktory (#{
                 metadata.jobtype
               }) jid-#{metadata.jid} #{inspect(metadata.args)}"
    end

    test "should log a failed 'FAIL' ack event" do
      outcome = %{status: :error}

      metadata = %{
        jid: Random.job_id(),
        args: %{hey: "there!"},
        jobtype: "TestQueueWorker"
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :failed_ack], outcome, metadata, [])
        end)

      assert log_message =~
               "[faktory-worker] Error sending 'FAIL' acknowledgement to faktory (#{
                 metadata.jobtype
               }) jid-#{metadata.jid} #{inspect(metadata.args)}"
    end

    test "should log job timeouts" do
      metadata = %{
        jid: Random.job_id(),
        args: %{hey: "there!"},
        jobtype: "TestQueueWorker"
      }

      log_message =
        capture_log(fn ->
          Telemetry.handle_event([:faktory_worker, :job_timeout], nil, metadata, [])
        end)

      assert log_message =~
               "[faktory-worker] Job has reached its reservation timeout and will be failed (#{
                 metadata.jobtype
               }) jid-#{metadata.jid} #{inspect(metadata.args)}"
    end
  end
end
