defmodule FaktoryWorker.Batch do
  alias FaktoryWorker.Random
  alias FaktoryWorker.Job

  defmacro __using__(using_opts \\ []) do
    alias FaktoryWorker.Batch

    quote do
      def perform_async_batch(description, success_job, complete_job, jobs, opts \\ []) do
        opts = Keyword.merge(unquote(using_opts), opts)

        batch_new_payload =
          __MODULE__
          |> Batch.build_batch_new_payload(description, success_job, complete_job, opts)

        batch_new_payload
        |> Batch.perform_async_batch(:batch_new, opts)

        jobs =
          jobs
          |> Enum.map(fn job ->
            job =
              case Keyword.get(job, :custom, nil) do
                nil ->
                  Keyword.put(job, :custom, %{bid: batch_new_payload.bid})

                items ->
                  custom = Keyword.merge([custom: %{bid: batch_new_payload.bid}], items)
                  Keyword.replace(job, :custom, custom)
              end

            __MODULE__
            |> Job.build_payload(job, opts)
            |> Job.perform_async(opts)
          end)

        Batch.perform_async_batch(batch_new_payload.bid, :batch_commit, opts)
      end
    end
  end

  @doc false
  def build_batch_new_payload(
        worker_module,
        description,
        {success_job, success_options} = _success,
        {complete_job, complete_options} = _complete) do
    bid = Random.job_id()

    success_options = Keyword.merge([custom: %{bid: bid}], success_options)

    success_job = Job.build_payload(worker_module, success_job, success_options)

    complete_options = Keyword.merge([custom: %{bid: bid}], complete_options)

    complete_job = Job.build_payload(worker_module, complete_job, complete_options)

    %{
      bid: bid,
      description: description,
      success: success_job,
      complete: complete_job
    }
  end

  @doc false
  def perform_async_batch(_, {:error, _} = error, _), do: error

  @doc false
  def perform_async_batch(payload, action, opts) do
    opts
    |> push_pipeline_name()
    |> perform_async_batch(payload, action, opts)
  end

  def perform_async_batch(pipeline_name, payload, action, _opts) do
    message = %Broadway.Message{
      acknowledger: {FaktoryWorker.PushPipeline.Acknowledger, :push_message, []},
      data: {pipeline_name, payload, action}
    }

    Broadway.push_messages(pipeline_name, [message])
  end

  defp push_pipeline_name(opts) do
    opts
    |> Keyword.get(:faktory_name, FaktoryWorker)
    |> FaktoryWorker.PushPipeline.format_pipeline_name()
  end
end
