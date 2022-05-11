# Mutate API

From the [Faktory documentation](https://github.com/contribsys/faktory/wiki/Mutate-API):

> It's inevitable: you will have cases where you enqueue bad data or have jobs
> which need pruning, migration or some other rare use case. For this, Faktory
> provides low-level data management APIs so you can script certain repairs or
> migrations.

> Please be warned: MUTATE commands can be slow and/or resource intensive.
> They should not be used as part of your application logic.

## Usage (Experimental)

Support for the Mutate API is currently very basic. At some point in the future,
this may be enhanced with a first-class Elixir API, but for now calls must be
made manually:

```elixir
args = %{
  cmd: "kill",
  target: "default",
  filter: %{jobtype: "MyApp.Job"}
}

FaktoryWorker.send_command({:mutate, args})
```

See [here](https://github.com/contribsys/faktory/wiki/Mutate-API#mutate) for the
full `MUTATE` argument reference.
