defmodule FaktoryWorker.Sandbox do
  @moduledoc """
  # TODO: write module documentation
  """

  use GenServer

  alias FaktoryWorker.{Job, JobSupervisor}

  @typedoc "A concise description of a single call to a job module."
  @type job :: %{worker: module(), args: list(), opts: Keyword.t()}

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec active? :: boolean()
  def active?, do: !!GenServer.whereis(__MODULE__)

  @spec job_supervisor :: module()
  def job_supervisor, do: GenServer.call(__MODULE__, :job_supervisor)

  @spec enqueue_job(module(), list(), Keyword.t()) :: :ok
  def enqueue_job(worker_mod, args, opts) do
    GenServer.call(__MODULE__, {:enqueue, worker_mod, args, opts})
  end

  @spec find_jobs(module(), args: list(), opts: Keyword.t()) :: [job()]
  def find_jobs(worker_mod, filters) do
    GenServer.call(__MODULE__, {:find_jobs, worker_mod, filters})
  end

  @spec all_jobs :: [job()]
  def all_jobs, do: GenServer.call(__MODULE__, :all_jobs)

  @spec all_jobs(module()) :: [job()]
  def all_jobs(worker_mod), do: GenServer.call(__MODULE__, {:all_jobs, worker_mod})

  @spec reset :: :ok
  def reset, do: GenServer.call(__MODULE__, :reset)

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

  @impl true
  def init(opts) do
    {:ok, %{jobs: %{}, opts: opts}}
  end

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
end
