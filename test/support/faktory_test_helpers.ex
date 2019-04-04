defmodule FaktoryWorker.FaktoryTestHelpers do
  @moduledoc false

  import ExUnit.Assertions

  def assert_queue_size(queue_name, expected_size) do
    Process.sleep(50)
    {:ok, connection} = FaktoryWorker.Connection.open()
    {:ok, info} = FaktoryWorker.Connection.send_command(connection, :info)

    assert get_in(info, ["faktory", "queues", queue_name]) == expected_size
  end
end
