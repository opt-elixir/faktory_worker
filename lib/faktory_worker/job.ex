defmodule FaktoryWorker.Job do
  @moduledoc """
  The `FaktoryWorker.Job` module is used to perform jobs in the background by sending to and fetching from Faktory.

  To build a worker you must `use` the job module within a module in your application.

  ```elixir
  defmodule MyApp.SomeWorker do
    use FaktoryWorker.Job
  end
  ```

  This will bring in all of the functionality required to perform jobs via Faktory. The `MyApp.SomeWorker` will now
  have a `perform_async/2` function available for sending jobs to Faktory. Before this function can be called, a
  `perform` function must be defined. This function must accept the same number of arguments that are
  being sent to Faktory via the `perform_async/2` function.

  ```elixir
  defmodule MyApp.SomeWorker do
    use FaktoryWorker.Job

    def perform(job_arg) do
      do_some_work(job_arg)
    end
  end
  ```

  With this in place it is now possible to send work to Faktory and the `MyApp.SomeWorker` will fetch the job and call
  the `perform/1` function with the same job arguments that we sent.

  ```elixir
  > MyApp.SomeWorker.perform_async("job arg")
  :ok
  ```

  It is also possible to send multiple arguments for a single job by passing in a list of values to the `perform_async/2`
  function.

  ```elixir
  > MyApp.SomeWorker.perform_async(["job arg1", "job arg2"])
  :ok
  ```

  In order for the job to be performed correctly, a `perform/2` function needs to be defined within the `MyApp.SomeWorker`
  module.

  ```elixir
  defmodule MyApp.SomeWorker do
    use FaktoryWorker.Job

    def perform(job_arg1, job_arg2) do
      do_some_work(job_arg1, job_arg2)
    end
  end
  ```

  When defining `perform` functions, they must always accept one argument for each item in the list of values passed into
  `perform_async/2`.

  ## Synchronous job pushing

  Previous version used Broadway to send jobs and `:skip_pipeline` parameter was used to do it synchronously.
  `:skip_pipeline` is not supported anymore.
  Since Batch operations is a feature of Faktory Enterprise this library now sends any single job synchronously
  and makes HTTP call to faktory server (see `FaktoryWorker.Batch`).

  ## Worker Configuration

  A list of options can be specified when using the the `FaktoryWorker.Job` module. These options will be used when sending
  jobs to faktory and will apply to all jobs sent with the `perform_async/2` function.

  For a full list of configuration options see the [Worker Configuration](configuration.html#worker-configuration) documentation.

  ## Overriding Worker Configuration

  The `perform_async/2` function accepts a keyword list as its second argument. This list has the same options
  available that the `FaktoryWorker.Job` module accepts. Any options passed into this function override the options
  that have been set on the worker module.

  For a full list of configuration options see the [Worker Configuration](configuration.html#worker-configuration) documentation.

  ## Data Serialization

  Faktory expects all values to be serialized in JSON format. FaktoryWorker uses `Jason` for serialization. This
  means only values that implement the `Jason.Encoder` protocol are valid when calling the `perform_async/2` function.
  """

  alias FaktoryWorker.{Random, Telemetry, Sandbox}

  # Look at supporting the following optional fields when pushing a job
  # priority
  # backtrace
  # created_at
  @optional_job_fields [:jobtype, :queue, :custom, :retry, :reserve_for, :at]

  @default_push_timeout 5000

  defmacro __using__(using_opts \\ []) do
    alias FaktoryWorker.Job

    quote do
      def perform_async(job, opts \\ []) do
        opts = Keyword.merge(unquote(using_opts), opts)

        __MODULE__
        |> Job.build_payload(job, opts)
        |> Job.perform_async(opts)
      end
    end
  end

  @doc false
  def build_payload(worker_module, job, opts) when is_list(job) do
    %{
      jid: Random.job_id(),
      jobtype: job_type_for_module(worker_module),
      args: normalize_job_args(job)
    }
    |> append_optional_fields(opts)
  end

  def build_payload(worker_module, job, opts) do
    build_payload(worker_module, [job], opts)
  end

  @doc false
  def perform_async(payload, opts) do
    if Sandbox.active?() do
      Sandbox.enqueue_job(
        String.to_existing_atom("Elixir." <> payload.jobtype),
        payload.args,
        opts
      )

      {:ok, payload}
    else
      opts
      |> faktory_name()
      |> push(payload)
    end
  end

  @doc false
  def normalize_job_args(args) when is_list(args) do
    Enum.map(args, fn
      %_{} = arg -> Map.from_struct(arg)
      arg -> arg
    end)
  end

  @doc false
  def push(_, invalid_payload = {:error, _}), do: invalid_payload

  def push(faktory_name, job) do
    {:push, job}
    |> FaktoryWorker.send_command(faktory_name: faktory_name, timeout: @default_push_timeout)
    |> handle_push_result(job)
  end

  defp append_optional_fields(args, opts) do
    Enum.reduce_while(@optional_job_fields, args, fn field, args ->
      case Keyword.get(opts, field) do
        nil ->
          {:cont, args}

        value ->
          if is_valid_field_value?(field, value) do
            value = format_field_value(value)
            {:cont, Map.put(args, field, value)}
          else
            {:halt, {:error, field_error_message(field, value)}}
          end
      end
    end)
  end

  defp is_valid_field_value?(:jobtype, value), do: is_binary(value)
  defp is_valid_field_value?(:queue, value), do: is_binary(value)
  defp is_valid_field_value?(:custom, value), do: is_map(value)
  defp is_valid_field_value?(:retry, value), do: is_integer(value)
  defp is_valid_field_value?(:reserve_for, value), do: is_integer(value) and value >= 60
  defp is_valid_field_value?(:at, %DateTime{}), do: true
  defp is_valid_field_value?(_, _), do: false

  defp format_field_value(%DateTime{} = date_time) do
    DateTime.to_iso8601(date_time)
  end

  defp format_field_value(value), do: value

  defp field_error_message(field, value) do
    "The field '#{Atom.to_string(field)}' has an invalid value '#{inspect(value)}'"
  end

  defp faktory_name(opts) do
    Keyword.get(opts, :faktory_name, FaktoryWorker)
  end

  defp handle_push_result({:ok, _}, job) do
    Telemetry.execute(:push, :ok, job)

    {:ok, job}
  end

  defp handle_push_result({:error, :timeout}, job) do
    Telemetry.execute(:push, {:error, :timeout}, job)

    {:error, :timeout}
  end

  defp handle_push_result({:error, reason}, _) do
    {:error, reason}
  end

  defp job_type_for_module(module) do
    module
    |> to_string()
    |> String.trim_leading("Elixir.")
  end
end
