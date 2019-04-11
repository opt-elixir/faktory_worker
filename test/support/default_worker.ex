defmodule FaktoryWorker.DefaultWorker do
  @moduledoc false
  use FaktoryWorker.Job

  def perform(_), do: :ok
end
