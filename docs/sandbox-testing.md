# Sandbox Testing

When testing your application, you may not want to actually push/pull jobs to
Faktory, but instead rely on asserting that jobs _would be_ enqueued as you
expect. Enabling sandbox mode will accomodate this; when sandbox mode is active,
the following changes are made:

- no connection will be made to Faktory (you don't even need a Faktory server running!)
- jobs enqueued (with `perform_async/2`) will **never** be run
- jobs enqueued will be recorded, and can be viewed using `FaktoryWorker.Sandbox`

To enable sandbox mode, set `:sandbox` to `true`:

```elixir
# config/test.exs

config :my_app, FaktoryWorker, sandbox: true
```

```elixir
# lib/my_app/application.ex

defmodule MyApp.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {FaktoryWorker, Application.get_env(:my_app, FaktoryWorker)}
    ]

    opts = [name: MyApp.Supervisor, strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
```

You can verify that sandbox mode is enabled with `FaktoryWorker.Sandbox.active?/0`.

## Writing Tests

To aid in tests that rely on jobs being enqueued, as well as tests for job modules
themselves, you can use the helpers in `FaktoryWorker.Testing`. Below is a simple
test for a module that enqueues a job:

```elixir
defmodule MyApp.QueueTest do
  use ExUnit.Case

  import FaktoryWorker.Testing

  setup do
    reset_queues()
  end

  test "perform/1" do
    MyApp.Job.perform_async("hello, world!")
    assert_enqueued MyApp.Job, args: ["hello, world!"]
    refute_enqueued MyApp.Job, args: ["goodbye!"]
  end

  test "perform/2" do
    MyApp.Job.perform_async(["foo", "bar"])
    assert_enqueued MyApp.Job, args: ["foo", "bar"]
  end

  test "with opts" do
    MyApp.Job.perform_async("howdy", reserve_for: 1_500)
    assert_enqueued MyApp.Job, opts: [reserve_for: 1_500]

    # these would work too!
    # assert_enqueued MyApp.Job, args: ["howdy"]
    # assert_enqueued MyApp.Job, args: ["howdy"], opts: [reserve_for: 1_500]
  end
end
```

Here's a simple example test for a job module itself:

```elixir
defmodule MyApp.JobTest do
  use ExUnit.Case

  import FaktoryWorker.Testing

  test "handles strings" do
    assert perform_job(MyApp.Job, "foo") == :ok
  end

  test "handles maps" do
    assert perform_job(MyApp.Job, %{id: 1}) == {:ok, "cool, a map!"}
  end

  test "handles structs" do
    # structs are serialized and passed to `perform` as bare maps
    assert perform_job(MyApp.Job, %MyApp.User{id: 1}) == {:ok, "cool, a map!"}
  end

  test "doesn't handle numbers" do
    assert perform_job(MyApp.Job, 1_234) == {:error, "boo, no numbers!"}
  end

  test "gracefully handles raises" do
    assert perform_job(MyApp.Job, "I'll cause a raise!") == {:error, "raise reason"}
  end
end
```

When you can, prefer to use `perform_job/3` instead of calling `perform` directly, as
it will ensure that the code under test is run in the same way that it will eventually
be at runtime.
