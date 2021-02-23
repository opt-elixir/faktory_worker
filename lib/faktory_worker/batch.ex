defmodule FaktoryWorker.Batch do
  @moduledoc """
  Supports Faktory Batch operations

  [Batch support](https://github.com/contribsys/faktory/wiki/Ent-Batches) is a
  Faktory Enterprise feature.

  Jobs pushed as part of a batch _must_ be pushed synchronously. This can be
  done using the `skip_pipeline: true` option when calling `perform_async/2`.
  """
  alias FaktoryWorker.{ConnectionManager, Job, Pool}

  @type bid :: String.t()

  @default_timeout 5000

  @doc """
  Creates a new Faktory batch

  Takes the description of the batch job, a string, and the options necessary to
  create the batch job.

  Returns the batch ID (`bid`) which needs to be passed in the `:custom`
  parameters of every job that should be part of this batch as well as to commit
  the batch.

  ## Opts

  Batch jobs must define a success or complete callback (or both). These
  callbacks are passed as tuples to the `:on_success` and `:on_complete` opts.
  They are defined as a tuple consisting of `{mod, args, opts}` where `mod` is a
  module with a `perform` function that corresponds in arity to the length of `args`.

  Any `opts` that can be passed to `perform_async/2` can be provided as `opts`
  to the callback except for `:faktory_worker`.

  If neither callback is provided, an error will be raised.

  ### `:on_success`

  See above.

  ### `:on_complete`

  See above.

  ### `:parent_bid`

  The parent batch ID--only used if you are creating a child batch.

  ### `:faktory_worker`

  The name of the `FaktoryWorker` instance (determines which connection pool
  will be used).
  """
  @spec new!(String.t(), Keyword.t()) :: {:ok, bid()}
  def new!(description, opts \\ []) do
    success = Keyword.get(opts, :on_success)
    complete = Keyword.get(opts, :on_complete)
    bid = Keyword.get(opts, :parent_id)

    payload =
      %{description: description}
      |> maybe_put_parent_id(bid)
      |> maybe_put_callback(:success, success)
      |> maybe_put_callback(:complete, complete)
      |> validate!()

    send_command({:batch_new, payload}, opts)
  end

  @doc """
  Commits the batch identified by `bid`

  Faktory will begin scheduling jobs that are part of the batch before the batch
  is committed, but
  """
  def commit(bid, opts \\ []) do
    send_command({:batch_commit, bid}, opts)
  end

  @doc """
  Opens the batch identified by `bid`

  An existing batch needs to be re-opened in order to add more jobs to it or to
  add a child batch.

  After opening the batch, it must be committed again using `commit/2`.
  """
  def open(bid, opts \\ []) do
    send_command({:batch_open, bid}, opts)
  end

  @doc """
  Gets the status of a batch

  Returns a map representing the status
  """
  def status(bid, opts \\ []) do
    send_command({:batch_status, bid}, opts)
  end

  defp send_command(command, opts) do
    opts
    |> Keyword.get(:faktory_name, FaktoryWorker)
    |> Pool.format_pool_name()
    |> :poolboy.transaction(
      &ConnectionManager.Server.send_command(&1, command),
      @default_timeout
    )
  end

  defp maybe_put_parent_id(payload, nil), do: payload
  defp maybe_put_parent_id(payload, bid), do: Map.put_new(payload, :parent_bid, bid)

  defp maybe_put_callback(payload, _type, nil), do: payload

  defp maybe_put_callback(payload, type, {mod, job, opts}) do
    job_payload = Job.build_payload(mod, job, opts)

    Map.put_new(payload, type, job_payload)
  end

  defp validate!(payload) do
    success = Map.get(payload, :success)
    complete = Map.get(payload, :complete)

    case {success, complete} do
      {nil, nil} ->
        raise("Faktory batch jobs must declare a success or complete callback")

      {_, _} ->
        payload
    end
  end
end
