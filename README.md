# Faktory Worker

A worker client for [Faktory](https://github.com/contribsys/faktory).

## Documentation

Faktory Worker documentation is available at [https://hexdocs.pm/faktory_worker](https://hexdocs.pm/faktory_worker).

## Getting up and running

To get started with Faktory Worker first add the dependency to your `mix.exs` file.

```elixir
defp deps do
  [
    {:faktory_worker, "~> 1.9.0"}
  ]
end
```

Faktory Worker can then be configured to start as part of your application by adding it to the `Application.start/2` function.

```elixir
defmodule MyApp.Application do
  use Application

  def start(_, _) do
    children = [
      FaktoryWorker
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: MyApp.Supervisor
    )
  end
end
```

Make sure you have configured your application to start in your `mix.exs` file.

```elixir
def application do
  [
    mod: {MyApp.Application, []}
  ]
end
```

This will start Faktory Worker using the default configuration. For details on how to configure Faktory Worker
see the [FaktoryWorker](https://hexdocs.pm/faktory_worker/faktory-worker.html#content) documentation.

Next you can create a worker to handle job processing.

```elixir
defmodule MyApp.SomeWorker do
  use FaktoryWorker.Job

  def perform(job_data) do
    do_some_work(job_data)
  end
end
```

Now you can start sending jobs to faktory and they will be automatically picked up by the worker.

```elixir
:ok = MyApp.SomeWorker.perform_async("hey there!")
```
#### Important! Since version 1.6.1 Broadway was removed from dependencies and response from perfomr_async is tuple {:ok, job_meta} with meta information about scheduled job.
```elixir
{:ok, job_meta} = MyApp.SomeWorker.perform_async("hey there!")
```

## Sending multiple job arguments

It's possible to send more than one argument to Faktory by passing a list of data to `perform_async/1`. Picking up from the example in the [Getting up and running](#getting-up-and-running) section we can modify our worker by adding another `perform` function with an arity that matches the number of job arguments we expect to send to Faktory.

```elixir
defmodule MyApp.SomeWorker do
  use FaktoryWorker.Job

  ...

  def perform(arg1, arg2) do
    do_some_work(arg1, arg2)
  end
end
```

With this new function in place you can now send multiple job arguments to Faktory.

```elixir
:ok = MyApp.SomeWorker.perform_async(["arg 1", "arg 2"])
```

## Configuration

The full list of configuration options are available in the [Configuration](https://hexdocs.pm/faktory_worker/configuration.html#content) documentation.

## Logging

By default Faktory Worker will not output any log messages but instead emit events using the [Telemetry](https://github.com/beam-telemetry/telemetry) library.

To enable the built in logging you will need to attach the default Telemetry handler provided by FaktoryWorker. The ideal place to do this is in your `Application.start/2` callback.

```elixir
defmodule MyApp.Application do
  use Application

  def start(_, _) do
    FaktoryWorker.attach_default_telemetry_handler()

    ...
  end
end
```

With this in place Faktory Worker will now output log messages for each of the events emitted.

For a full list of Faktory Worker events or for details on handling these events see the [Logging](https://hexdocs.pm/faktory_worker/logging.html#content) documentation.

## Contributing

We always appreciate contributions whether they are testing, reporting issues, feedback or submitting PRs. If you would like to work on Faktory Worker please follow the [Developing](#developing) section for details on how to get setup for developing and running the test suite.

## Developing

Faktory Worker includes a docker compose file that provisions all of the Faktory instances required to run the test suite.

If you have docker compose installed you can run the `up` command from the Faktory Worker directory to start everything required.

```sh
$ docker-compose up -d
Creating faktory_worker_test          ... done
Creating faktory_worker_test_tls      ... done
Creating faktory_worker_password_test ... done
```


Faktory have free open-source solution and enterprise edition.

If you don't have enterprise license then tests will fail on enterprise features (batching operations etc). In this case you can exclude them by tag `:enterprise`
```sh
$ mix test --exclude enterprise
```

If you are enterprise user all tests should pass
```sh
$ mix test
```
