defmodule FaktoryWorker.WorkerLoggerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias FaktoryWorker.WorkerLogger
  alias FaktoryWorker.Random

  describe "log_push/2" do
    test "should log a push success" do
      job_id = Random.job_id()
      args = %{hey: "there!"}

      log_message =
        capture_log(fn ->
          WorkerLogger.log_push(job_id, args)
        end)

      assert log_message =~ "[faktory-worker] Enqueued jid-#{job_id} #{inspect(args)}"
    end
  end

  describe "log_ack/3" do
    test "should log a successful job ack" do
      job_id = Random.job_id()
      args = %{hey: "there!"}

      log_message =
        capture_log(fn ->
          WorkerLogger.log_ack(:ok, job_id, args)
        end)

      assert log_message =~ "[faktory-worker] Succeeded jid-#{job_id} #{inspect(args)}"
    end

    test "should log a failed job ack" do
      job_id = Random.job_id()
      args = %{hey: "there!"}

      log_message =
        capture_log(fn ->
          WorkerLogger.log_ack(:error, job_id, args)
        end)

      assert log_message =~ "[faktory-worker] Failed jid-#{job_id} #{inspect(args)}"
    end
  end

  describe "log_failed_ack/3" do
    test "should log failed to send 'ACK'" do
      job_id = Random.job_id()
      args = %{hey: "there!"}

      log_message =
        capture_log(fn ->
          WorkerLogger.log_failed_ack(:ok, job_id, args)
        end)

      assert log_message =~
               "[faktory-worker] Error sending 'ACK' acknowledgement to faktory jid-#{job_id} #{
                 inspect(args)
               }"
    end

    test "should log failed to send 'FAIL'" do
      job_id = Random.job_id()
      args = %{hey: "there!"}

      log_message =
        capture_log(fn ->
          WorkerLogger.log_failed_ack(:error, job_id, args)
        end)

      assert log_message =~
               "[faktory-worker] Error sending 'FAIL' acknowledgement to faktory jid-#{job_id} #{
                 inspect(args)
               }"
    end
  end

  describe "log_beat/2" do
    test "should log a successful beat when previous beat failed" do
      worker_id = Random.process_wid()

      log_message =
        capture_log(fn ->
          WorkerLogger.log_beat(:ok, :error, worker_id)
        end)

      assert log_message =~ "[faktory-worker] Heartbeat Succeeded wid-#{worker_id}"
    end

    test "should log a failed beat when previous beat succeeded" do
      worker_id = Random.process_wid()

      log_message =
        capture_log(fn ->
          WorkerLogger.log_beat(:error, :ok, worker_id)
        end)

      assert log_message =~ "[faktory-worker] Heartbeat Failed wid-#{worker_id}"
    end

    test "should not log when the beat state did not change" do
      worker_id = Random.process_wid()

      log_message =
        capture_log(fn ->
          WorkerLogger.log_beat(:ok, :ok, worker_id)
        end)

      assert log_message == ""
    end
  end

  describe "log_fetch/3" do
    test "should log a failed fetch" do
      worker_id = Random.process_wid()

      log_message =
        capture_log(fn ->
          WorkerLogger.log_fetch(:error, worker_id, "Shutdown in progress")
        end)

      assert log_message =~
               "[faktory-worker] Failed to fetch job due to 'Shutdown in progress' wid-#{
                 worker_id
               }"
    end
  end
end
