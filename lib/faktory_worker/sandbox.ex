defmodule FaktoryWorker.Sandbox do
  @moduledoc """
  When started with sandbox mode enabled, `FaktoryWorker` won't connect
  to a running Faktory instance or perform queued jobs, but will instead
  record all jobs enqueued locally.

  In general, this mode should only be used during testing. See
  [Sandbox Testing](sandbox-testing.html) to read more.
  """

  use GenServer

  alias FaktoryWorker.Job
  alias FaktoryWorker.JobSupervisor

  @typedoc "A concise description of a single call to a job module."
  @type job :: %{worker: module(), args: list(), opts: Keyword.t()}

  @doc false
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns true if sandbox mode is enabled."
  @spec active? :: boolean()
  def active?, do: !!GenServer.whereis(__MODULE__)

  @doc false
  @spec job_supervisor :: module()
  def job_supervisor, do: GenServer.call(__MODULE__, :job_supervisor)

  @doc false
  @spec enqueue_job(module(), list(), Keyword.t()) :: :ok
  def enqueue_job(worker_mod, args, opts) do
    GenServer.call(__MODULE__, {:enqueue, worker_mod, args, opts})
  end

  @doc false
  @spec find_jobs(module(), args: list(), opts: Keyword.t()) :: [job()]
  def find_jobs(worker_mod, filters) do
    GenServer.call(__MODULE__, {:find_jobs, worker_mod, filters})
  end

  @doc """
  Returns a list of all locally enqueued jobs across all job modules, in
  the order that they were enqueued. If you only want to retrieve jobs
  enqueued for a specific job module, use `all_jobs/1` instead.
  """
  @spec all_jobs :: [job()]
  def all_jobs, do: GenServer.call(__MODULE__, :all_jobs)

  @doc """
  Returns a list of all locally enqueued jobs for the given job module,
  in the order that they were enqueued. If you want to retrieve a list of
  all jobs across all job modules, use `all_jobs/0` instead.
  """
  @spec all_jobs(module()) :: [job()]
  def all_jobs(worker_mod), do: GenServer.call(__MODULE__, {:all_jobs, worker_mod})

  @doc "Clear the queue history for all job modules."
  @spec reset :: :ok
  def reset, do: GenServer.call(__MODULE__, :reset)

  @doc "Clear the queue history for the given job module."
  @spec reset(module()) :: :ok
  def reset(worker_mod), do: GenServer.call(__MODULE__, {:reset, worker_mod})

  @doc false
  @spec encode_args(term() | list(term())) :: list()
  def encode_args(args) when is_list(args) do
    with args <- Job.normalize_job_args(args),
         {:ok, encoded} <- Jason.encode(args),
         {:ok, decoded} <- Jason.decode(encoded) do
      decoded
    else
      {:error, reason} ->
        raise "unable to encode arguments: #{reason} (attempted to encode #{inspect(args)})"
    end
  end

  def encode_args(arg), do: encode_args([arg])

  # ---

  @doc false
  @impl true
  def init(opts) do
    {:ok, %{jobs: %{}, opts: opts}}
  end

  @doc false
  @impl true
  def handle_call(:job_supervisor, _from, state) do
    {:reply, JobSupervisor.format_supervisor_name(state.opts[:name]), state}
  end

  def handle_call({:enqueue, worker_mod, args, opts}, _from, state) do
    job = %{
      worker: worker_mod,
      args: encode_args(args),
      opts: opts
    }

    jobs = Map.update(state.jobs, worker_mod, [job], &Enum.concat(&1, [job]))
    {:reply, :ok, %{state | jobs: jobs}}
  end

  def handle_call({:find_jobs, worker_mod, filters}, _from, state) do
    jobs =
      Enum.filter(state.jobs[worker_mod] || [], fn %{args: args, opts: opts} ->
        match? =
          if filters[:args] do
            args == encode_args(filters[:args])
          else
            true
          end

        match? =
          if filters[:opts] do
            Enum.reduce(filters[:opts], match?, fn {key, val}, acc ->
              acc and opts[key] == val
            end)
          else
            match?
          end

        match?
      end)

    {:reply, jobs, state}
  end

  def handle_call(:all_jobs, _from, state) do
    jobs =
      state.jobs
      |> Map.values()
      |> List.flatten()

    {:reply, jobs, state}
  end

  def handle_call({:all_jobs, worker_mod}, _from, state) do
    {:reply, state.jobs[worker_mod] || [], state}
  end

  def handle_call(:reset, _from, state) do
    {:reply, :ok, %{state | jobs: %{}}}
  end

  def handle_call({:reset, worker_mod}, _from, state) do
    jobs = Map.update(state.jobs, worker_mod, %{}, fn _ -> %{} end)
    {:reply, :ok, %{state | jobs: jobs}}
  end

  def batch_id, do: "sandbox-batch-id"

  def batch_status, do: %{
    "bid" => batch_id(),
    "total" => 10,
    "pending" => 14,
    "failed" => 3,
    "created_at" =>  "2019-11-18T13:48:25Z",
    "description" => "This is a sandbox status"
  }
end
