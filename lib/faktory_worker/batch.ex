defmodule FaktoryWorker.Batch do
  alias FaktoryWorker.{ConnectionManager, Job, Pool}

  @default_timeout 5000

  @doc """
  Builds a batch new struct with a parent bid if specified

  args should be formatted: [on_complete: {mod, args, opts}, on_success: {mod, args, opts}, parent_id: bid]

  ## Example

  iex> args = [on_complete: {DefaultWorker, %{hey: "you!"}, [faktory_name: faktory_name]}]
  iex> build_payload("description", args)
    %{
      complete: %{
        args: [%{hey: "you!"}],
        jid: "6ce7e595b572bd142abfb607",
        jobtype: "DefaultWorker"
      },
      description: "description"
    }

  """
  def build_payload(
        description,
        args
      ) do
    success = Keyword.get(args, :on_success, nil)
    complete = Keyword.get(args, :on_complete, nil)
    bid = Keyword.get(args, :parent_id, nil)

    %{description: description}
    |> maybe_put_parent_id(bid)
    |> maybe_put_callback(:success, success)
    |> maybe_put_callback(:complete, complete)
    |> validate()
  end

  defp maybe_put_parent_id(payload, bid) do
    case bid do
      nil ->
        payload

      bid ->
        payload
        |> Map.put_new(:parent_bid, bid)
    end
  end

  defp maybe_put_callback(payload, callback_type, callback) do
    case callback do
      nil ->
        payload

      callback ->
        {callback_worker_module, callback_job, callback_options} = callback
        callback_job = Job.build_payload(callback_worker_module, callback_job, callback_options)

        payload
        |> Map.put_new(callback_type, callback_job)
    end
  end

  defp validate(payload) do
    success = payload |> Map.get(:success, nil)
    complete = payload |> Map.get(:complete, nil)

    case {success, complete} do
      {nil, nil} ->
        {:error, "Success or Complete must be defined"}

      {_, _} ->
        {:ok, payload}
    end
  end

  @doc """
  Issues a batch new request to the Faktory instance specified in the options
  """
  def new(payload, opts) do
    opts
    |> send_command({:batch_new, payload})
  end

  @doc """
  Issues a batch commit request to the Faktory instance specified in the options
  """
  def commit(bid, opts) do
    opts
    |> send_command({:batch_commit, bid})
  end

  @doc """
  Issues a batch open request to the Faktory instance specified in the options
  """
  def open(bid, opts) do
    opts
    |> send_command({:batch_open, bid})
  end

  defp send_command(opts, command) do
    opts
    |> Keyword.get(:faktory_name, FaktoryWorker)
    |> Pool.format_pool_name()
    |> :poolboy.transaction(
      &ConnectionManager.Server.send_command(&1, command),
      @default_timeout
    )
  end
end
