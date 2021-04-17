defmodule FaktoryWorker.Testing do
  @moduledoc """
  # TODO: write module documentation
  """

  import ExUnit.Assertions, only: [assert: 2, refute: 2]

  alias FaktoryWorker.Sandbox

  @faktory_default_reserve_for 1_800

  @spec perform_job(module(), term() | [term()], Keyword.t()) :: Macro.t()
  defmacro perform_job(worker_mod, arg_or_args, opts \\ []) do
    quote do
      alias FaktoryWorker.Sandbox

      args = Sandbox.encode_args(unquote(arg_or_args))

      %Task{ref: job_ref} =
        Task.Supervisor.async_nolink(
          Sandbox.job_supervisor(),
          unquote(worker_mod),
          :perform,
          args,
          shutdown: :brutal_kill
        )

      # FIXME: is this the correct place to check for :reserve_for?
      reserve_for_seconds =
        get_in(unquote(opts), [:custom, :reserve_for]) || unquote(@faktory_default_reserve_for)

      timeout = (reserve_for_seconds - 20) * 1_000

      receive do
        {^job_ref, resp} ->
          Process.demonitor(job_ref, [:flush])
          resp

        {:DOWN, ^job_ref, :process, _pid, {%{message: reason}, _stacktrace}} ->
          {:error, reason}

        {:DOWN, ^job_ref, :process, _pid, reason} ->
          {:error, reason}
      after
        timeout ->
          {:error, :timeout}
      end
    end
  end

  @spec reset_queues :: :ok
  def reset_queues, do: Sandbox.reset()

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
