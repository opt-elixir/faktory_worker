defmodule FaktoryWorker.JobSupervisorTest do
  use ExUnit.Case

  alias FaktoryWorker.JobSupervisor

  describe "child_spec/1" do
    test "should return a default child_spec" do
      opts = [name: FaktoryWorker]
      child_spec = JobSupervisor.child_spec(opts)

      assert child_spec == %{
               id: FaktoryWorker_job_supervisor,
               start: {Task.Supervisor, :start_link, [[name: FaktoryWorker_job_supervisor]]}
             }
    end

    test "should allow a custom name to be specified" do
      opts = [name: :test_faktory]
      child_spec = JobSupervisor.child_spec(opts)

      assert child_spec == %{
               id: :test_faktory_job_supervisor,
               start: {Task.Supervisor, :start_link, [[name: :test_faktory_job_supervisor]]}
             }
    end
  end

  describe "format_supervisor_name/1" do
    test "should return the full job supervisor name" do
      name = JobSupervisor.format_supervisor_name(:test_faktory)

      assert name == :test_faktory_job_supervisor
    end
  end
end
