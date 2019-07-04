defmodule FaktoryWorker.ErrorFormatter do
  @moduledoc false

  defmodule FormattedError do
    @moduledoc false

    defstruct [:type, :message, :stacktrace]
  end

  def format_error(error, max_stacktrace_length) do
    {type, message, stacktrace} = split_error_reason(error)

    message = limit_error_length(message)

    stacktrace =
      stacktrace
      |> Enum.take(max_stacktrace_length)
      |> Enum.map(&Exception.format_stacktrace_entry/1)

    %FormattedError{
      type: type || "Undetected Error Type",
      message: message,
      stacktrace: stacktrace
    }
  end

  defp split_error_reason({%struct_type{} = struct, stacktrace}) when is_list(stacktrace) do
    message = Map.get(struct, :message)

    {Atom.to_string(struct_type), message || inspect(struct), stacktrace}
  end

  defp split_error_reason({%{message: message}, stacktrace})
       when is_binary(message) and is_list(stacktrace) do
    {nil, message, stacktrace}
  end

  defp split_error_reason({{error_type, _} = reason, stacktrace})
       when is_atom(error_type) and is_list(stacktrace) do
    {Atom.to_string(error_type), format_reason(reason), stacktrace}
  end

  defp split_error_reason({reason, stacktrace}) when is_list(stacktrace) do
    {nil, format_reason(reason), stacktrace}
  end

  defp split_error_reason(reason) do
    {nil, format_reason(reason), []}
  end

  defp format_reason(reason) when is_atom(reason) do
    Atom.to_string(reason)
  end

  defp format_reason(reason), do: inspect(reason)

  defp limit_error_length(error) when byte_size(error) > 1000 do
    reduce_string(error, 1000)
  end

  defp limit_error_length(error), do: error

  defp reduce_string(string, length) do
    reduced_string = :binary.part(string, {0, length})

    if String.printable?(reduced_string),
      do: reduced_string,
      else: reduce_string(reduced_string, length - 1)
  end
end
