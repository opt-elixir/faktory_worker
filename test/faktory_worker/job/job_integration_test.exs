defmodule FaktoryWorker.JobIntegrationTest do
  use ExUnit.Case

  alias FaktoryWorker.Job

  describe "perform_async/3" do
    test "should send a new job to faktory" do
      faktory_name = :"Test_#{random_string()}"
      start_supervised!({FaktoryWorker, name: faktory_name, pool: [size: 1]})

      queue_name = random_string()

      opts = [
        queue: queue_name,
        faktory_name: faktory_name
      ]

      job = Job.build_payload(SomeWorker, %{hey: "there!"}, opts)

      Job.perform_async(job, opts)

      assert_queue_size(queue_name, 1)

      :ok = stop_supervised(faktory_name)
    end
  end

  defp assert_queue_size(queue_name, expected_size) do
    Process.sleep(20)
    {:ok, connection} = FaktoryWorker.Connection.open()
    {:ok, info} = FaktoryWorker.Connection.send_command(connection, :info)

    assert get_in(info, ["faktory", "queues", queue_name]) == expected_size
  end

  defp random_string() do
    bytes = :crypto.strong_rand_bytes(12)
    Base.encode16(bytes)
  end
end
