defmodule FaktoryWorker.ProtocolTest do
  use ExUnit.Case, async: true

  alias FaktoryWorker.Protocol

  describe "encode_command/1" do
    test "should encode the 'HELLO' command" do
      {:ok, command} = Protocol.encode_command({:hello, %{v: 2}})

      assert command == "HELLO {\"v\":2}\r\n"
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
  end
end
