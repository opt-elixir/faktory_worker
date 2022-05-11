defmodule FaktoryWorker do
  @moduledoc """
  The `FaktoryWorker` module provides everything required to setup workers for sending and fetching jobs.

  It is expected that FaktoryWorker will be configured and started as part of a supervision tree. Multiple instances of
  FaktoryWorker can be configured by providing the `:name`  option which must be unique.

  This module can either be configured using all default options.

  ```elixir
  children = [
    FaktoryWorker
  ]
  ```

  Or by using the two element tuple format accepting a list of options as the second element.

  ```elixir
  children = [
    {FaktoryWorker, [name: :faktory_test, ...]}
  ]
  ```

  For a full list of configuration options see the [Configuration](configuration.html) documentation.
  """

  alias FaktoryWorker.{ConnectionManager, Pool}

  @default_timeout 5_000

  @doc false
  def child_spec(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)

    children =
      if opts[:sandbox] do
        [
          {FaktoryWorker.JobSupervisor, opts},
          {FaktoryWorker.Sandbox, opts}
        ]
      else
        [
          {FaktoryWorker.QueueManager, opts},
          {FaktoryWorker.Pool, opts},
          {FaktoryWorker.JobSupervisor, opts},
          {FaktoryWorker.WorkerSupervisor, opts}
        ]
      end

    %{
      id: opts[:name],
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end

  @doc """
  Attaches the default telemetry handler provided by FaktoryWorker.

  This function attaches the default telemetry handler provided by FaktoryWorker that
  outputs log messages for each of the events emitted by FaktoryWorker.

  For a full list of events see the [Logging](logging.html) documentation.
  """
  @spec attach_default_telemetry_handler :: :ok | {:error, :already_exists}
  def attach_default_telemetry_handler() do
    FaktoryWorker.Telemetry.attach_default_handler()
  end

  @type command :: FaktoryWorker.Protocol.protocol_command()

  @type send_command_opt :: {:faktory_name, module()} | {:timeout, pos_integer()}

  @doc """
  Send a command to the Faktory server.

  In most cases, `FaktoryWorker` handles sending commands on your behalf.
  However, there are some APIs (such as Enterprise Batches and Tracking)
  where it's useful to send a command directly.

  The full list of supported commands is available in
  `FaktoryWorker.Protocol.protocol_command()`. It is left to the caller to
  verify that command arguments are valid.

  ## Options

  - `faktory_name` the Faktory instance to use (default: #{inspect(__MODULE__)})
  - `timeout` how long to wait for a response, in ms (default: #{@default_timeout})

  """
  @spec send_command(command(), [send_command_opt()]) :: FaktoryWorker.Connection.response()
  def send_command(command, opts \\ []) do
    opts
    |> Keyword.get(:faktory_name, __MODULE__)
    |> Pool.format_pool_name()
    |> :poolboy.transaction(
      &ConnectionManager.Server.send_command(&1, command),
      Keyword.get(opts, :timeout, @default_timeout)
    )
  end
end
