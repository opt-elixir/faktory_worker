defmodule FaktoryWorker.Job.JobTest do
  use ExUnit.Case, async: true

  alias FaktoryWorker.Job

  defmodule TestWorker do
    use FaktoryWorker.Job,
      queue: "test_queue",
      concurrency: 10

    def perform(_), do: :ok
  end

  defmodule OverridesWorker do
    use FaktoryWorker.Job,
      queue: "override_queue",
      concurrency: 5,
      retry: 10,
      reserve_for: 600,
      custom: %{"unique_for" => 60}

    def perform(_), do: :ok
  end

  defstruct [:value]

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

    test "should be able to pass in a struct as a job arg" do
      data = %__MODULE__{value: "hey there!"}
      job = Job.build_payload(Test.Worker, data, [])

      assert job.jid != nil
      assert job.jobtype == "Test.Worker"
      assert job.args == [%{value: "hey there!"}]
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
      error = Job.build_payload(Test.Worker, data, opts)

      assert error == {:error, "The field 'queue' has an invalid value '123'"}
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
      error = Job.build_payload(Test.Worker, data, opts)

      assert error == {:error, "The field 'custom' has an invalid value '[1, 2, 3]'"}
    end

    test "should be able to specify the retry field" do
      data = %{hey: "there!"}
      opts = [retry: 20]
      job = Job.build_payload(Test.Worker, data, opts)

      assert job.retry == 20
    end

    test "should not be able to specify invalid data for the retry field" do
      data = %{hey: "there!"}
      opts = [retry: "20"]
      error = Job.build_payload(Test.Worker, data, opts)

      assert error == {:error, "The field 'retry' has an invalid value '\"20\"'"}
    end

    test "should be able to specify the reserve_for field" do
      data = %{hey: "there!"}
      opts = [reserve_for: 120]
      job = Job.build_payload(Test.Worker, data, opts)

      assert job.reserve_for == 120
    end

    test "should not be able to specify invalid data for the reserve_for field" do
      data = %{hey: "there!"}
      opts = [reserve_for: "120"]
      error = Job.build_payload(Test.Worker, data, opts)

      assert error == {:error, "The field 'reserve_for' has an invalid value '\"120\"'"}
    end

    test "should not be able to specify a value less than 60 for the reserve_for field" do
      data = %{hey: "there!"}
      opts = [reserve_for: 59]
      error = Job.build_payload(Test.Worker, data, opts)

      assert error == {:error, "The field 'reserve_for' has an invalid value '59'"}
    end

    test "should set the job id to a long string" do
      job = Job.build_payload(Test.Worker, 123, [])

      assert byte_size(job.jid) == 24
    end

    test "should be able to specify an 'at' date/time" do
      data = %{hey: "there!"}
      opts = [at: DateTime.from_naive!(~N[2020-03-16 13:26:08.003], "Etc/UTC")]
      job = Job.build_payload(Test.Worker, data, opts)

      assert job.at == "2020-03-16T13:26:08.003Z"
    end

    test "should not be able to specify an invalid data type for the 'at' date/time" do
      data = %{hey: "there!"}
      opts = [at: "not a date/time"]
      error = Job.build_payload(Test.Worker, data, opts)

      assert error == {:error, "The field 'at' has an invalid value '\"not a date/time\"'"}
    end

    test "should be able to specify a a custom jobtype" do
      data = %{hey: "there!"}
      opts = [jobtype: "custom_job_type"]
      job = Job.build_payload(Test.Worker, data, opts)

      assert job.jobtype == "custom_job_type"
    end

    test "should return an error for a non binary jobtype" do
      data = %{hey: "there!"}
      opts = [jobtype: 1]
      error = Job.build_payload(Test.Worker, data, opts)

      assert error == {:error, "The field 'jobtype' has an invalid value '1'"}
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

end
