# Faktory Worker

A worker client for [Faktory](https://github.com/contribsys/faktory).

## Documentation

Faktory Worker documentation is available at [https://hexdocs.pm/faktory_worker](https://hexdocs.pm/faktory_worker).

## Getting up and running

To get started with Faktory Worker first add the dependancy to your `mix.exs` file.

```elixir
defp deps do
  [
    {:faktory_worker, "~> 1.0.0"}
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
see the [FaktoryWorker](faktoryworker.html) documentation.

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

## Sending multiple job arguments

It's possible to send more that one argument to Faktory by passing a list of data to `perform_async/1`. Picking up from the example in the [Getting up and running](#getting-up-and-running) section we can modify our worker by adding another `perform` function with an artity that matches the number of job arguments we expect to send to Faktory.

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

The full list of configuration options are available in the [Configuration](configuration.html) documentation.

## Contributing

We always appreciate contributions whether they are testing, reporting issues, feedback or submitting PRs. If you would like to work on Faktory Worker please follow the [Developing](#developing) section for details on how to get setup for developing and running the test suite.

## Developing

Faktory Worker includes a docker compose file that provisons all of the Faktory instances required to run the test suite.

If you have docker compose installed you can run the `up` command from the Faktory Worker directory to start everything required.

```sh
$ docker-compose up -d
Creating faktory_worker_test          ... done
Creating faktory_worker_test_tls      ... done
Creating faktory_worker_password_test ... done

$ mix test
```
