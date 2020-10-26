defmodule FaktoryWorker.FaktoryTestHelpers do
  @moduledoc false

  import ExUnit.Assertions

  def flush_faktory!(_context) do
    {:ok, conn} = FaktoryWorker.Connection.open()
    {:ok, "OK"} = FaktoryWorker.Connection.send_command(conn, :flush)
    :ok
  end

  def assert_queue_size(queue_name, expected_size) do
    Process.sleep(50)
    {:ok, connection} = FaktoryWorker.Connection.open()
    {:ok, info} = FaktoryWorker.Connection.send_command(connection, :info)

    assert get_in(info, ["faktory", "queues", queue_name]) == expected_size
  end

  def get_info() do
    Process.sleep(50)
    {:ok, connection} = FaktoryWorker.Connection.open()
    FaktoryWorker.Connection.send_command(connection, :info)
  end

  def get_batch_created_size() do
    Process.sleep(50)
    {:ok, connection} = FaktoryWorker.Connection.open()

    {:ok, info} = FaktoryWorker.Connection.send_command(connection, :info)
    Kernel.get_in(info, ["faktory", "tasks", "batch", "created"])
  end

  def get_connections() do
    Process.sleep(50)
    {:ok, connection} = FaktoryWorker.Connection.open()

    {:ok, info} = FaktoryWorker.Connection.send_command(connection, :info)
    Kernel.get_in(info, ["server", "connections"])
  end

  def get_batch_status(bid) do
    Process.sleep(50)
    {:ok, connection} = FaktoryWorker.Connection.open()

    {:ok, info} = FaktoryWorker.Connection.send_command(connection, {:batch_status, bid})
  end
end
