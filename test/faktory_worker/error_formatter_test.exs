defmodule FaktoryWorker.ErrorFormatterTest do
  use ExUnit.Case

  alias FaktoryWorker.ErrorFormatter
  alias FaktoryWorker.ErrorFormatter.FormattedError

  describe "format_error/2" do
    @stacktrace [
      {TestApp.Worker, :raise_error, 1, [file: ~c"lib/worker.ex", line: 50]},
      {TestApp.Worker, :do_work, 1, [file: ~c"lib/worker.ex", line: 37]},
      {TestApp.Worker, :perform, 1, [file: ~c"lib/worker.ex", line: 9]}
    ]

    @formatted_stacktrace [
      "lib/worker.ex:50: TestApp.Worker.raise_error/1",
      "lib/worker.ex:37: TestApp.Worker.do_work/1",
      "lib/worker.ex:9: TestApp.Worker.perform/1"
    ]

    test "should return a formatted error for an exception" do
      error = %RuntimeError{message: "It went bang!"}

      formatted_error = ErrorFormatter.format_error({error, @stacktrace}, 10)

      assert formatted_error == %FormattedError{
               type: "Elixir.RuntimeError",
               message: "It went bang!",
               stacktrace: @formatted_stacktrace
             }
    end

    test "should return a formatted error for a map with a message attribute" do
      error = %{message: "It went bang!"}

      formatted_error = ErrorFormatter.format_error({error, @stacktrace}, 10)

      assert formatted_error == %FormattedError{
               type: "Undetected Error Type",
               message: "It went bang!",
               stacktrace: @formatted_stacktrace
             }
    end

    test "should return a formatted error for a tuple with an atom error type" do
      error = {:badmatch, "123"}

      formatted_error = ErrorFormatter.format_error({error, @stacktrace}, 10)

      assert formatted_error == %FormattedError{
               type: "badmatch",
               message: "{:badmatch, \"123\"}",
               stacktrace: @formatted_stacktrace
             }
    end

    test "should return a formatted error for an unkown error type with a stacktrace" do
      error = :exit

      formatted_error = ErrorFormatter.format_error({error, @stacktrace}, 10)

      assert formatted_error == %FormattedError{
               type: "Undetected Error Type",
               message: "exit",
               stacktrace: @formatted_stacktrace
             }
    end

    test "should return a formatted error for an unkown error type without a stacktrace" do
      error = :exit

      formatted_error = ErrorFormatter.format_error(error, 10)

      assert formatted_error == %FormattedError{
               type: "Undetected Error Type",
               message: "exit",
               stacktrace: []
             }
    end

    test "should limit the length of the stacktrace" do
      %{stacktrace: stacktrace} = ErrorFormatter.format_error({:exit, @stacktrace}, 2)

      assert length(stacktrace) == 2
    end

    test "should limit the error message length to 1000 bytes" do
      error = %RuntimeError{message: String.duplicate("A", 1001)}

      %{message: message} = ErrorFormatter.format_error({error, @stacktrace}, 2)

      assert byte_size(message) == 1000
    end

    test "should limit the error message length to less than 1000 bytes when truncating renders an invalid character" do
      # this string will be 1001 bytes since the 'ñ' using 2 bytes
      error_message = "#{String.duplicate("A", 999)}ñ"
      error = %RuntimeError{message: error_message}

      %{message: message} = ErrorFormatter.format_error({error, @stacktrace}, 2)

      assert byte_size(message) == 999
    end

    test "should use a default error type when the type is unknown" do
      %{type: type} = ErrorFormatter.format_error({:error, @stacktrace}, 10)

      assert type == "Undetected Error Type"
    end
  end
end
