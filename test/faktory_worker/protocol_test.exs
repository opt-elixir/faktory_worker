defmodule FaktoryWorker.ProtocolTest do
  use ExUnit.Case, async: true

  alias FaktoryWorker.Protocol
  alias FaktoryWorker.Random

  describe "encode_command/1" do
    test "should encode the 'HELLO' command" do
      {:ok, command} = Protocol.encode_command({:hello, %{v: 2}})

      assert command == "HELLO {\"v\":2}\r\n"
    end

    test "should encode the 'PUSH' command" do
      {:ok, command} =
        Protocol.encode_command(
          {:push,
           %{jid: "123456", jobtype: "TestJob", queue: "test_queue", args: [%{some: "values"}]}}
        )

      assert command ==
               "PUSH {\"args\":[{\"some\":\"values\"}],\"jid\":\"123456\",\"jobtype\":\"TestJob\",\"queue\":\"test_queue\"}\r\n"
    end

    test "should encode the 'BEAT' command" do
      worker_id = Random.process_wid()
      {:ok, command} = Protocol.encode_command({:beat, worker_id})

      assert command == "BEAT {\"wid\":\"#{worker_id}\"}\r\n"
    end

    test "should encode the 'INFO' command" do
      {:ok, command} = Protocol.encode_command(:info)

      assert command == "INFO\r\n"
    end

    test "should encode the 'END' command" do
      {:ok, command} = Protocol.encode_command(:end)

      assert command == "END\r\n"
    end

    test "should encode the 'FLUSH' command" do
      {:ok, command} = Protocol.encode_command(:flush)

      assert command == "FLUSH\r\n"
    end

    test "should encode the 'FETCH' command with a list of queues" do
      {:ok, command} = Protocol.encode_command({:fetch, ["queue_one", "queue_two"]})

      assert command == "FETCH queue_one queue_two\r\n"
    end

    test "should encode the 'FETCH' command with default queue when list of queues is empty" do
      {:ok, command} = Protocol.encode_command({:fetch, []})

      assert command == "FETCH default\r\n"
    end

    test "should encode the 'ACK' command" do
      {:ok, command} = Protocol.encode_command({:ack, "1234567890"})

      assert command == "ACK {\"jid\":\"1234567890\"}\r\n"
    end

    test "should encode the 'FAIL' command" do
      payload = %{
        jid: "1234567890",
        errtype: "Some error",
        message: "It went bang!",
        backtrace: ["file2.ex, line: 34", "file.ex, line: 1"]
      }

      {:ok, command} = Protocol.encode_command({:fail, payload})

      assert command ==
               "FAIL {\"backtrace\":[\"file2.ex, line: 34\",\"file.ex, line: 1\"],\"errtype\":\"Some error\",\"jid\":\"1234567890\",\"message\":\"It went bang!\"}\r\n"
    end

    test "should return an error when attempting to encode bad data" do
      {:error, reason} = Protocol.encode_command({:hello, {:v, 2}})

      assert reason == "Invalid command args '{:v, 2}' given and could not be encoded"
    end
  end

  describe "decode_response/1" do
    test "should decode the 'HI' response" do
      {:ok, resposne} = Protocol.decode_response("+HI {\"v\":2}\r\n")

      assert resposne == %{"v" => 2}
    end

    test "should decode the 'OK' response" do
      {:ok, resposne} = Protocol.decode_response("+OK\r\n")

      assert resposne == "OK"
    end

    test "should decode the '-ERR' response" do
      {:error, resposne} = Protocol.decode_response("-ERR Some error\r\n")

      assert resposne == "Some error"
    end

    test "should decode the '-SHUTDOWN' response" do
      {:error, resposne} = Protocol.decode_response("-SHUTDOWN Shutdown in progress\r\n")

      assert resposne == "Shutdown in progress"
    end

    test "should decode the '$n' bulk string response" do
      {:ok, resposne} = Protocol.decode_response("$592\r\n")

      assert resposne == {:bulk_string, 594}
    end

    test "should decode a null bulk string response" do
      {:ok, resposne} = Protocol.decode_response("$-1\r\n")

      assert resposne == :no_content
    end

    test "should decode bulk string response" do
      {:ok, response} = Protocol.decode_response("{\"some\":\"longer\",\"response\":\"data\"}")

      assert response == %{
               "response" => "data",
               "some" => "longer"
             }
    end

    test "should decode a json hash response" do
      {:ok, resposne} = Protocol.decode_response("+{\"hey\":\"there!\"}\r\n")

      assert resposne == %{"hey" => "there!"}
    end
  end
end
