defmodule FaktoryWorker.Job do
  @moduledoc """
  todo: docs
  """

  # Look at supporting the following optional fields when pushing a job
  # priority
  # reserve_for
  # at
  # retry
  # backtrace
  # created_at
  # custom
  @optional_job_fields [:queue]

  defmacro __using__(using_opts \\ []) do
    alias FaktoryWorker.Job

    quote do
      def perform_async(job, opts \\ []) do
        opts = Keyword.merge(unquote(using_opts), opts)
        Job.perform_async(__MODULE__, job, opts)
      end
    end
  end

  @doc false
  def perform_async(worker_module, job, opts) when is_list(job) do
    pipeline_name = push_pipeline_name(opts)

    args =
      %{
        jid: random_job_id(),
        jobtype: job_type_for_module(worker_module),
        args: job
      }
      |> append_optional_fields(opts)

    message = %Broadway.Message{
      acknowledger: {FaktoryWorker.PushPipeline.Acknowledger, :push_message, []},
      data: args
    }

    Broadway.push_messages(pipeline_name, [message])
  end

  def perform_async(queue, job, opts) do
    perform_async(queue, [job], opts)
  end

  defp append_optional_fields(args, opts) do
    Enum.reduce(@optional_job_fields, args, fn field, args ->
      case Keyword.get(opts, field) do
        nil -> args
        value -> Map.put(args, field, value)
      end
    end)
  end

  defp push_pipeline_name(opts) do
    opts
    |> Keyword.get(:faktory_name, FaktoryWorker)
    |> FaktoryWorker.PushPipeline.format_pipeline_name()
  end

  defp random_job_id() do
    rand_bytes = :crypto.strong_rand_bytes(12)
    Base.encode16(rand_bytes, case: :lower)
  end

  defp job_type_for_module(module) do
    module
    |> to_string()
    |> String.trim_leading("Elixir.")
  end
end
