defmodule FaktoryWorker.PushPipeline.ProducerTest do
  use ExUnit.Case

  alias FaktoryWorker.PushPipeline.Producer

  describe "init/1" do
    test "should return with default values" do
      {type, state, opts} = Producer.init([])

      assert type == :producer
      assert state == %{jobs: []}
      assert opts == [buffer_size: :infinity]
    end

    test "should return with configured buffer size" do
      {:producer, _, opts} = Producer.init(buffer_size: 5000)

      assert opts == [buffer_size: 5000]
    end
  end
end
