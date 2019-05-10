defmodule FaktoryWorker.WorkerLoggerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias FaktoryWorker.WorkerLogger
  alias FaktoryWorker.Random

  describe "log_push/2" do
    test "should log a push success" do
      job_id = Random.job_id()
      args = %{hey: "there!"}
      worker_module = "TestQueueWorker"

      log_message =
        capture_log(fn ->
          WorkerLogger.log_push(job_id, args, worker_module)
        end)

      assert log_message =~
               "[faktory-worker] Enqueued (#{worker_module}) jid-#{job_id} #{inspect(args)}"
    end
  end

  describe "log_ack/3" do
    test "should log a successful job ack" do
      job_id = Random.job_id()
      args = %{hey: "there!"}
      worker_module = "TestQueueWorker"

      log_message =
        capture_log(fn ->
          WorkerLogger.log_ack(:ok, job_id, args, worker_module)
        end)

      assert log_message =~
               "[faktory-worker] Succeeded (#{worker_module}) jid-#{job_id} #{inspect(args)}"
    end

    test "should log a failed job ack" do
      job_id = Random.job_id()
      args = %{hey: "there!"}
      worker_module = "TestQueueWorker"

      log_message =
        capture_log(fn ->
          WorkerLogger.log_ack(:error, job_id, args, worker_module)
        end)

      assert log_message =~
               "[faktory-worker] Failed (#{worker_module}) jid-#{job_id} #{inspect(args)}"
    end
  end

  describe "log_failed_ack/3" do
    test "should log failed to send 'ACK'" do
      job_id = Random.job_id()
      args = %{hey: "there!"}
      worker_module = "TestQueueWorker"

      log_message =
        capture_log(fn ->
          WorkerLogger.log_failed_ack(:ok, job_id, args, worker_module)
        end)

      assert log_message =~
               "[faktory-worker] Error sending 'ACK' acknowledgement to faktory (#{worker_module}) jid-#{
                 job_id
               } #{inspect(args)}"
    end

    test "should log failed to send 'FAIL'" do
      job_id = Random.job_id()
      args = %{hey: "there!"}
      worker_module = "TestQueueWorker"

      log_message =
        capture_log(fn ->
          WorkerLogger.log_failed_ack(:error, job_id, args, worker_module)
        end)

      assert log_message =~
               "[faktory-worker] Error sending 'FAIL' acknowledgement to faktory (#{worker_module}) jid-#{
                 job_id
               } #{inspect(args)}"
    end
  end

  describe "log_beat/2" do
    test "should log a successful beat when previous beat failed" do
      process_wid = Random.process_wid()

      log_message =
        capture_log(fn ->
          WorkerLogger.log_beat(:ok, :error, process_wid)
        end)

      assert log_message =~ "[faktory-worker] Heartbeat Succeeded wid-#{process_wid}"
    end

    test "should log a failed beat when previous beat succeeded" do
      process_wid = Random.process_wid()

      log_message =
        capture_log(fn ->
          WorkerLogger.log_beat(:error, :ok, process_wid)
        end)

      assert log_message =~ "[faktory-worker] Heartbeat Failed wid-#{process_wid}"
    end

    test "should not log when the beat state did not change" do
      process_wid = Random.process_wid()

      log_message =
        capture_log(fn ->
          WorkerLogger.log_beat(:ok, :ok, process_wid)
        end)

      assert log_message == ""
    end
  end

  describe "log_fetch/3" do
    test "should log a failed fetch" do
      process_wid = Random.process_wid()

      log_message =
        capture_log(fn ->
          WorkerLogger.log_fetch(:error, process_wid, "Shutdown in progress")
        end)

      assert log_message =~
               "[faktory-worker] Failed to fetch job due to 'Shutdown in progress' wid-#{
                 process_wid
               }"
    end
  end
end
