defmodule FaktoryWorker.EventLoggerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import FaktoryWorker.EventHandlerTestHelpers

  alias FaktoryWorker.Random
  alias FaktoryWorker.EventLogger

  describe "attach/3" do
    test "should attach the event logger to telemetry" do
      EventLogger.attach()

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
      assert handler_function == (&FaktoryWorker.EventLogger.handle_event/4)
      assert Enum.member?(handled_events, [:faktory_worker, :push])
      assert Enum.member?(handled_events, [:faktory_worker, :beat])
      assert Enum.member?(handled_events, [:faktory_worker, :fetch])
      assert Enum.member?(handled_events, [:faktory_worker, :ack])
      assert Enum.member?(handled_events, [:faktory_worker, :failed_ack])

      detach_event_handler(:faktory_worker_logger)
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
          EventLogger.handle_event([:faktory_worker, :push], outcome, metadata, [])
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
          EventLogger.handle_event([:faktory_worker, :push], outcome, metadata, [])
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
          EventLogger.handle_event([:faktory_worker, :beat], outcome, metadata, [])
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
          EventLogger.handle_event([:faktory_worker, :beat], outcome, metadata, [])
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
          EventLogger.handle_event([:faktory_worker, :beat], outcome, metadata, [])
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
          EventLogger.handle_event([:faktory_worker, :fetch], outcome, metadata, [])
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
          EventLogger.handle_event([:faktory_worker, :ack], outcome, metadata, [])
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
          EventLogger.handle_event([:faktory_worker, :ack], outcome, metadata, [])
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
          EventLogger.handle_event([:faktory_worker, :failed_ack], outcome, metadata, [])
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
          EventLogger.handle_event([:faktory_worker, :failed_ack], outcome, metadata, [])
        end)

      assert log_message =~
               "[faktory-worker] Error sending 'FAIL' acknowledgement to faktory (#{
                 metadata.jobtype
               }) jid-#{metadata.jid} #{inspect(metadata.args)}"
    end
  end
end
