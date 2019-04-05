defmodule FaktoryWorker.Job.JobTest do
  use ExUnit.Case, async: true

  alias FaktoryWorker.Job

  defmodule TestWorker do
    use FaktoryWorker.Job,
      queue: "test_queue",
      concurrency: 10
  end

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

    test "should not be able to specify an invalid data type for queue name" do
      data = %{hey: "there!"}
      opts = [queue: 123]
      job = Job.build_payload(Test.Worker, data, opts)

      assert job == {:error, "The field 'queue' has an invalid value '123'"}
    end

    test "should be able to specify a custom map of values" do
      data = %{hey: "there!"}
      opts = [custom: %{unique_for: 120}]
      job = Job.build_payload(Test.Worker, data, opts)

      assert job.custom == %{unique_for: 120}
    end

    test "should not be able to specify an invalid data type for custom data" do
      data = %{hey: "there!"}
      opts = [custom: [1, 2, 3]]
      job = Job.build_payload(Test.Worker, data, opts)

      assert job == {:error, "The field 'custom' has an invalid value '[1, 2, 3]'"}
    end

    test "should set the job id to a long string" do
      job = Job.build_payload(Test.Worker, 123, [])

      assert byte_size(job.jid) == 24
    end
  end

  describe "perform_async/2" do
    test "should not send a bad payload" do
      data = %{hey: "there!"}
      opts = [queue: 123]
      {:error, _} = payload = Job.build_payload(Test.Worker, data, opts)

      {:error, error} = Job.perform_async(payload, [])

      assert error == "The field 'queue' has an invalid value '123'"
    end
  end

  describe "perform_async/3" do
    test "should not send a bad payload" do
      data = %{hey: "there!"}
      opts = [queue: 123]
      {:error, _} = payload = Job.build_payload(Test.Worker, data, opts)

      {:error, error} = Job.perform_async(TestPipeline, payload, [])

      assert error == "The field 'queue' has an invalid value '123'"
    end
  end

  describe "__using__/1" do
    test "should make the worker config available via worker_config/0" do
      config = TestWorker.worker_config()

      assert Keyword.get(config, :queue) == "test_queue"
      assert Keyword.get(config, :concurrency) == 10
    end
  end
end
