defmodule FaktoryWorker.Testing do
  @moduledoc """
  Test utilities for asserting and refuting whether jobs are enqueued,
  as well as performing jobs as they will be performed when pulled off
  the queue at runtime.

  See [Sandbox Testing](sandbox-testing.html) to read more.
  """

  import ExUnit.Assertions, only: [assert: 2, refute: 2]

  alias FaktoryWorker.Sandbox
  alias FaktoryWorker.JobSupervisor

  @doc """
  Perform the job in the same way that it will be performed when pulled
  from the queue at runtime. Specifically, this means:

  - work will be done in a separate process, under a `Task.Supervisor`
  - job arguments will go through serialization/deserialization

  Blocks until the job has completed, returning the result of executing
  the `perform` function. If the job raises or exits, the return value
  will be `{:error, "raise or exit reason"}`. If the job times out
  (execution time exceeds the job's `:reserve_for` duration), `{:error, :timeout}`
  will be returned instead of the normal result.

  Note that `ExUnit.CaptureLog`, `ExUnit.CaptureIO`, and friends will
  **not** work since the job process is not linked to the caller.
  """
  @spec perform_job(module(), term() | [term()], Keyword.t()) :: Macro.t()
  defmacro perform_job(worker_mod, arg_or_args, opts \\ []) do
    quote do
      alias FaktoryWorker.Worker
      alias FaktoryWorker.Sandbox

      args = Sandbox.encode_args(unquote(arg_or_args))

      %Task{ref: job_ref} =
        JobSupervisor.async_nolink(
          Sandbox.job_supervisor(),
          unquote(worker_mod),
          args
        )

      timeout_duration =
        unquote(opts)
        |> Keyword.get_lazy(:reserve_for, &Worker.faktory_default_reserve_for/0)
        |> Worker.reserve_timeout_duration()

      receive do
        {^job_ref, resp} ->
          Process.demonitor(job_ref, [:flush])
          resp

        {:DOWN, ^job_ref, :process, _pid, {%{message: reason}, _stacktrace}} ->
          {:error, reason}

        {:DOWN, ^job_ref, :process, _pid, reason} ->
          {:error, reason}
      after
        timeout_duration ->
          {:error, :timeout}
      end
    end
  end

  @doc """
  Resets the queue history for all job modules.

  Generally, this should be called in the `setup` block for any tests that
  use `assert_enqueued/2` or `refute_enqueued/2`, to ensure that test cases
  don't pollute each other.

  This will reset the history for _all_ job modules; if you need finer-grained
  control over which job modules are reset (generally you shouldn't), use
  `FaktoryWorker.Sandbox.reset/1` instead.
  """
  @spec reset_queues :: :ok
  def reset_queues, do: Sandbox.reset()

  @doc """
  Assert that a job was enqueued for the given job module, optionally matching
  a set of argument/option filters. If multiple jobs were recorded that match,
  the assertion will still pass, so try to be as specific as possible.

  ## Examples

      defmodule MyApp.Test do
        use ExUnit.Case

        import FaktoryWorker.Testing

        setup do
          reset_queues()
        end

        test "enqueues" do
          MyApp.Job.perform_async("argument")

          # assert that _any_ job was enqueued for this module
          assert_enqueued MyApp.Job

          # assert that a specific job was enqueued
          assert_enqueued MyApp.Job, args: ["argument"]

          # assert on multiple arguments (order matters)
          assert_enqueued MyApp.Job, args: ["foo", "bar"]

          # assert on serializable arguments
          assert_enqueued MyApp.Job, args: [%MyApp.User{...}]

          # assert on options (only those explicitly passed to `perform_async`)
          assert_enqueued MyApp.Job, opts: [reserve_for: 1_500]

          # assert on multiple filters
          assert_enqueued MyApp.Job, args: ["foo", "bar"], opts: [custom: %{}]
        end
      end

  """
  @spec assert_enqueued(module(), args: list(), opts: Keyword.t()) :: true
  def assert_enqueued(worker_mod, filters \\ []) do
    validate_filters!(filters)

    err_message = """
    Expected a job to be enqueued matching:

    #{describe_filters(worker_mod, filters)}

    but didn't find one. These jobs were enqueued for #{inspect(worker_mod)}:

    #{describe_available_jobs(worker_mod)}
    """

    refute worker_mod |> Sandbox.find_jobs(filters) |> Enum.empty?(), err_message

    true
  end

  @doc """
  Assert that a job was **not** enqueued for the given job module, optionally
  specifying a set of argument/option filters.

  ## Examples

      defmodule MyApp.Test do
        use ExUnit.Case

        import FaktoryWorker.Testing

        setup do
          reset_queues()
        end

        test "doesn't enqueue" do
          # refute that _any_ job was enqueued for this module
          refute_enqueued MyApp.Job

          # refute that a specific job was enqueued
          refute_enqueued MyApp.Job, args: ["argument"]

          # refute on multiple arguments (order matters)
          refute_enqueued MyApp.Job, args: ["foo", "bar"]

          # refute on serializable arguments
          refute_enqueued MyApp.Job, args: [%MyApp.User{...}]

          # refute on options (only those explicitly passed to `perform_async`)
          refute_enqueued MyApp.Job, opts: [reserve_for: 1_500]

          # refute on multiple filters
          refute_enqueued MyApp.Job, args: ["foo", "bar"], opts: [custom: %{}]
        end
      end

  """
  @spec refute_enqueued(module(), args: list(), opts: Keyword.t()) :: false
  def refute_enqueued(worker_mod, filters \\ []) do
    validate_filters!(filters)

    jobs = Sandbox.find_jobs(worker_mod, filters)

    err_message = """
    Expected 0 jobs to be enqueued matching:

    #{describe_filters(worker_mod, filters)}

    but found #{length(jobs)}.

    #{describe_jobs(jobs)}
    """

    assert Enum.empty?(jobs), err_message

    false
  end

  # ---

  @spec validate_filters!(Keyword.t()) :: :ok
  defp validate_filters!(filters) do
    if not Keyword.keyword?(filters) do
      raise """
      assert_enqueued/refute_enqueued accept a keyword list of filters as
      the second argument, containing either a list of `:args` and/or a
      keyword list of `:opts`

      received #{inspect(filters)}
      """
    end

    Enum.each(filters, &validate_filter!/1)
  end

  @spec validate_filter!({:args | :opts, term()}) :: true
  defp validate_filter!({:args, arg_filter}) do
    err_message = """
    Expected a list of job arguments, but got:

    #{inspect(arg_filter)}

    Make sure to pass a _list_ of arguments, even if there's only one:

      assert_enqueued(MyApp.Job, args: ["single-argument"])

    """

    assert is_list(arg_filter), err_message
  end

  defp validate_filter!({:opts, opt_filter}) do
    err_message = """
    Expected a keyword list of job options, but got:

    #{inspect(opt_filter)}

    Make sure to pass a keyword list:

      assert_enqueued(MyApp.Job, opts: [queue: "another-queue"])

    """

    assert Keyword.keyword?(opt_filter), err_message
  end

  defp validate_filter!({key, _filter}) do
    raise """
    Received unexpected job filter #{inspect(key)}. Valid filters include:

      - :args
      - :opts

    If you were trying to filter by an option, make sure to nest the filter
    under the `:opts` key, like so:

      assert_enqueued(MyApp.Job, opts: [key: "value"])

    """
  end

  @spec describe_filters(module(), Keyword.t()) :: String.t()
  defp describe_filters(worker_mod, filters) do
    filters
    |> Keyword.put(:worker, worker_mod)
    |> inspect()
  end

  @spec describe_available_jobs(module()) :: String.t()
  defp describe_available_jobs(worker_mod) do
    worker_mod
    |> Sandbox.all_jobs()
    |> describe_jobs()
  end

  @spec describe_jobs([Sandbox.job()]) :: String.t()
  def describe_jobs(jobs) do
    jobs
    |> Enum.with_index(1)
    |> Enum.map(&describe_job/1)
    |> Enum.join("\n")
  end

  @spec describe_job({Sandbox.job(), pos_integer()}) :: String.t()
  defp describe_job({job, index}) do
    "  #{index}: ##{inspect(job.worker)}<args: #{inspect(job.args)}, opts: #{inspect(job.opts)}>"
  end
end
