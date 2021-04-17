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
          {FaktoryWorker.PushPipeline, opts},
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
end
