# Faktory Worker Configuration

## Available Configuration

Faktory Worker offers a range configuration options that are passed into the `FaktoryWorker` module directly when defining it as part of a supervision tree. All of these options are optional and have default values defined.

Configuration can be specified in the supervision tree using a two element tuple.

```elixir
defmodule MyApp.Application do
  use Application

  def start(_, _) do
    children = [
      {FaktoryWorker, [name: :faktory_test]}
    ]

    ...
  end
end
```

Below is the full structure of available options and a definition for each one.

```elixir
[
  name: atom(),
  connection: [
    host: String.t(),
    port: pos_integer(),
    password: String.t(),
    use_tls: boolean()
  ],
  pool: [
    size: pos_integer(),
    buffer_size: pos_integer() | :infinity
  ],
  worker_pool: [
    size: pos_integer(),
    disable_fetch: boolean(),
    queues: [
      list(String.t() | {String.t(), keyword()})
    ]
  ]
]
```

### Option Definitions

- `name` (default: `FaktoryWorker`) - The name to use for this instance. This is useful if you want to run more than one instance of Faktory Worker. When using this make sure the workers are configured to use the correct instance (see [Worker Configuration](#worker-configuration) below).

- `connection` - A list of options to configure the connection to Faktory.

  - `host` (default: `"localhost"`) - The host name used to connect to Faktory.
  - `port` (default: `7419`) - The tcp port used to connect to Faktory.
  - `password` (default: `nil`) - The password used to authenticate with Faktory.
  - `use_tls` (default: `false`) - A boolean flag that indicates whether Faktory Worker should connect using a TLS connection.

- `pool` - A list of options to configure the pool of Faktory connections used for sending jobs to Faktory.

  - `size` (default: `10`) - The number of connections to open to Faktory.
  - `buffer_size` (default: `:infinity`) - The number of jobs that can be stored in memory whilst waiting for an available connection from the pool. Note that this defaults to `:infinity` to prevent losing jobs during high load scenarios. This could potentially lead to increased memory consumption if there is low throughput to Faktory.

- `worker_pool` - A list of options to configure the Faktory workers.
  - `size` (default: `10`) - The number of worker connections to open to Faktory.
  - `disable_fetch` (default: `false`) - A boolean flag used to disable fetching on each of the workers. This is useful if you want to prevent the workers from fetching new jobs without having to remove the queues config.
  - `queues` (default: `["default"]`) - A list of queues that the workers should fetch jobs from. See the [Configuring Queues](#configuring-queues) section below for more details.

## Configuring Queues

Queues are configured by specifying a list of strings or tuples.

```elixir
queues: ["queue_name", {"another_queue", opts}]
```

The queue name must match the name of the queue in Faktory. Using the tuple definition allows a list of options to be specified when fetching jobs from that queue.

The available options are.

```elixir
[
  max_concurrency: pos_integer() | :infinity
]
```

### Option Definitions

- `max_concurrency` (default: `:infinity`) - The maximum number of jobs that should be fetched and processed from this queue in parallel.

## Worker Configuration

Workers can be configured with queue specific options that are used by Faktory Worker when sending jobs to Faktory. All of these options are optional and have default values.

Options are defined when using `FaktoryWorker.Job`.

```elixir
use FaktoryWorker.Job, opts
```

Below is the full structure of available options and a definition for each one.

```elixir
[
  queue: String.t(),
  retry: pos_integer(),
  reserve_for: post_integer(),
  custom: map(),
  faktory_name: atom()
]
```

### Option Definitions

- `queue` (default: `"default"`) - The name of the queue in Faktory to send jobs to.
- `retry` (relies on Faktory default) - The number of times the job should retry if it fails.
- `reserve_for` (relies on Faktory default) -The number of seconds the job is reserved for in Faktory before it is considered failed.
- `custom` (relies on Faktory default) - A map of values to be included with the job when it is sent to Faktory.
- `faktory_name` (default: `FaktoryWorker`) - The name of the Faktory instance to use when sending the job to Faktory.
