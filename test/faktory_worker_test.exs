defmodule FaktoryWorkerTest do
  use ExUnit.Case

  describe "child_spec/0" do
    test "should return a default child_spec" do
      child_spec = FaktoryWorker.child_spec()

      assert child_spec == default_child_spec()
    end
  end

  describe "child_spec/1" do
    test "should allow a name to be specified" do
      opts = [
        name: :my_test_faktory
      ]

      child_spec = FaktoryWorker.child_spec(opts)
      config = get_child_spec_config(child_spec)

      assert config == [
               {FaktoryWorker.Pool, [name: :my_test_faktory]},
               {FaktoryWorker.PushPipeline, [name: :my_test_faktory]},
               {FaktoryWorker.JobSupervisor, [name: :my_test_faktory]},
               {FaktoryWorker.WorkerSupervisor, [name: :my_test_faktory]}
             ]
    end

    test "should allow pool config to be specified" do
      opts = [
        pool: [
          size: 25
        ]
      ]

      child_spec = FaktoryWorker.child_spec(opts)
      config = get_child_spec_config(child_spec)

      assert config == [
               {FaktoryWorker.Pool, [name: FaktoryWorker, pool: [size: 25]]},
               {FaktoryWorker.PushPipeline, [name: FaktoryWorker, pool: [size: 25]]},
               {FaktoryWorker.JobSupervisor, [name: FaktoryWorker, pool: [size: 25]]},
               {FaktoryWorker.WorkerSupervisor, [name: FaktoryWorker, pool: [size: 25]]}
             ]
    end

    test "should allow connection configuration to be specified" do
      opts = [
        connection: [
          host: "somehost",
          port: 7519
        ]
      ]

      child_spec = FaktoryWorker.child_spec(opts)
      config = get_child_spec_config(child_spec)

      assert config == [
               {FaktoryWorker.Pool,
                [name: FaktoryWorker, connection: [host: "somehost", port: 7519]]},
               {FaktoryWorker.PushPipeline,
                [name: FaktoryWorker, connection: [host: "somehost", port: 7519]]},
               {FaktoryWorker.JobSupervisor,
                [name: FaktoryWorker, connection: [host: "somehost", port: 7519]]},
               {FaktoryWorker.WorkerSupervisor,
                [name: FaktoryWorker, connection: [host: "somehost", port: 7519]]}
             ]
    end
  end

  defp default_child_spec() do
    %{
      id: FaktoryWorker,
      start:
        {Supervisor, :start_link,
         [
           [
             {FaktoryWorker.Pool, [name: FaktoryWorker]},
             {FaktoryWorker.PushPipeline, [name: FaktoryWorker]},
             {FaktoryWorker.JobSupervisor, [name: FaktoryWorker]},
             {FaktoryWorker.WorkerSupervisor, [name: FaktoryWorker]}
           ],
           [strategy: :one_for_one]
         ]},
      type: :supervisor
    }
  end

  defp get_child_spec_config(%{start: start_config}) do
    {Supervisor, :start_link,
     [
       config,
       [strategy: :one_for_one]
     ]} = start_config

    config
  end
end
