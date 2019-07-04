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

    children = [
      {FaktoryWorker.QueueManager, opts},
      {FaktoryWorker.Pool, opts},
      {FaktoryWorker.PushPipeline, opts},
      {FaktoryWorker.JobSupervisor, opts},
      {FaktoryWorker.WorkerSupervisor, opts}
    ]

    %{
      id: opts[:name],
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end
end
