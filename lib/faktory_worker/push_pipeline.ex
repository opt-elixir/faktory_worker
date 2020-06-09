defmodule FaktoryWorker.PushPipeline do
  @moduledoc false

  use Broadway

  alias FaktoryWorker.PushPipeline.Consumer

  # todo: I think we can split this up to make the options built in start_link testable

  @spec start_link(opts :: keyword()) :: {:ok, pid()} | {:error, any()} | :ignore
  def start_link(opts) do
    pool_config = Keyword.get(opts, :pool, [])
    pool_size = Keyword.get(pool_config, :size, 10)

    Broadway.start_link(__MODULE__,
      name: format_pipeline_name(opts[:name]),
      context: %{name: opts[:name]},
      producer: [
        module: {FaktoryWorker.PushPipeline.Producer, pool_config},
        concurrency: pool_size
      ],
      processors: [
        default: [concurrency: pool_size]
      ],
      batchers: [
        default: [concurrency: pool_size, batch_size: 1]
      ]
    )
  end

  @impl true
  def handle_batch(batcher, messages, batch_info, context) do
    Consumer.handle_batch(batcher, messages, batch_info, context)
  end

  @impl true
  def handle_message(processor_name, message, context) do
    Consumer.handle_message(processor_name, message, context)
  end

  @spec format_pipeline_name(name :: atom()) :: atom()
  def format_pipeline_name(name) when is_atom(name) do
    :"#{name}_pipeline"
  end
end
