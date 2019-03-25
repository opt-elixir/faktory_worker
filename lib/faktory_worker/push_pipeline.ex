defmodule FaktoryWorker.PushPipeline do
  @moduledoc false

  use Broadway

  alias FaktoryWorker.PushPipeline.Consumer

  # todo: I think we can split this up to make the options built in start_link testable

  def start_link(opts) do
    pool_config = Keyword.get(opts, :pool, [])
    pool_size = Keyword.get(pool_config, :size, 10)

    Broadway.start_link(__MODULE__,
      name: :"#{opts[:name]}_pipeline",
      producers: [
        default: [
          module: {FaktoryWorker.PushPipeline.Producer, []},
          stages: pool_size
        ]
      ],
      processors: [
        default: [stages: pool_size]
      ],
      batchers: [
        default: [stages: pool_size, batch_size: 1]
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
end
