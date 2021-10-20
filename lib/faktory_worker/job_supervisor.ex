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

  @spec async_nolink(module(), module(), list()) :: Task.t()
  def async_nolink(job_supervisor, job_module, job_args) do
    Task.Supervisor.async_nolink(
      job_supervisor,
      job_module,
      :perform,
      job_args,
      shutdown: :brutal_kill
    )
  end
end
