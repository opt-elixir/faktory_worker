defmodule FaktoryWorker.JobSupervisor do
  @moduledoc false

  def child_spec(opts) do
    name = format_supervisor_name(opts[:name])

    %{
      id: name,
      start: {Task.Supervisor, :start_link, [[name: name]]}
    }
  end

  def format_supervisor_name(name) when is_atom(name) do
    :"#{name}_job_supervisor"
  end
end
