defmodule FaktoryWorker.Job.JobTest do
  use ExUnit.Case, async: true

  alias FaktoryWorker.Job

  describe "build_payload/3" do
    test "should create new faktory job struct" do
      data = %{hey: "there!"}
      job = Job.build_payload(Test.Worker, [data], [])

      assert job.jid != nil
      assert job.jobtype == "Test.Worker"
      assert job.args == [data]
    end

    test "should be able to pass in multiple job args" do
      data = %{hey: "there!"}
      job = Job.build_payload(Test.Worker, ["some_text", data, 123], [])

      assert job.jid != nil
      assert job.jobtype == "Test.Worker"
      assert job.args == ["some_text", data, 123]
    end

    test "should be able to pass in a non list job arg" do
      data = %{hey: "there!"}
      job = Job.build_payload(Test.Worker, data, [])

      assert job.jid != nil
      assert job.jobtype == "Test.Worker"
      assert job.args == [data]
    end

    test "should be able to specify a queue name" do
      data = %{hey: "there!"}
      opts = [queue: "test_queue"]
      job = Job.build_payload(Test.Worker, data, opts)

      assert job.queue == "test_queue"
    end

    test "should set the job id to a long string" do
      job = Job.build_payload(Test.Worker, 123, [])

      assert byte_size(job.jid) == 24
    end
  end
end
