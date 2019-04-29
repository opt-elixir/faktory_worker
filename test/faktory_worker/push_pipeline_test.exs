defmodule FaktoryWorker.PushPipelineTest do
  use ExUnit.Case

  alias FaktoryWorker.PushPipeline

  describe "child_spec/1" do
    test "should return a default child_spec" do
      opts = [name: FaktoryWorker]

      assert %{
               id: FaktoryWorker.PushPipeline,
               start: {FaktoryWorker.PushPipeline, :start_link, [[name: FaktoryWorker]]}
             } = PushPipeline.child_spec(opts)
    end

    test "should allow a custom name to be specified" do
      opts = [
        name: :my_test_faktory
      ]

      child_spec = PushPipeline.child_spec(opts)
      config = get_child_spec_config(child_spec)

      assert config[:name] == :my_test_faktory
    end

    test "should allow pool config to be specified" do
      opts = [
        name: FaktoryWorker,
        pool: [
          size: 25
        ]
      ]

      child_spec = PushPipeline.child_spec(opts)
      config = get_child_spec_config(child_spec)

      assert config[:pool][:size] == 25
    end
  end

  describe "start_link/1" do
    test "should start the pipeline" do
      opts = [name: FaktoryWorker]
      pid = start_supervised!(FaktoryWorker.PushPipeline.child_spec(opts))

      assert pid == Process.whereis(FaktoryWorker_pipeline)

      :ok = stop_supervised(FaktoryWorker.PushPipeline)
    end
  end

  describe "format_pipeline_name/1" do
    test "should append a suffix to the given name" do
      assert :my_test_pipeline == PushPipeline.format_pipeline_name(:my_test)
    end
  end

  defp get_child_spec_config(child_spec) do
    %{
      id: FaktoryWorker.PushPipeline,
      start: {FaktoryWorker.PushPipeline, :start_link, [config]}
    } = child_spec

    config
  end
end
