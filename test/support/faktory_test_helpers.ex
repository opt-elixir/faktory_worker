defmodule FaktoryWorker.FaktoryTestHelpers do
  @moduledoc false

  import ExUnit.Assertions

  def assert_queue_size(queue_name, expected_size) do
    Process.sleep(20)
    {:ok, connection} = FaktoryWorker.Connection.open()
    {:ok, info} = FaktoryWorker.Connection.send_command(connection, :info)

    assert get_in(info, ["faktory", "queues", queue_name]) == expected_size
  end

  def random_string() do
    bytes = :crypto.strong_rand_bytes(12)
    Base.encode16(bytes)
  end
end
