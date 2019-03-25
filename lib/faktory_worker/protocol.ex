defmodule FaktoryWorker.Protocol do
  @moduledoc false

  @type protocol_command :: {:hello, map()}

  @spec encode_command(command :: protocol_command()) :: {:ok, String.t()} | {:error, term()}
  def encode_command({:hello, args}) do
    encode("HELLO", args)
  end

  @spec decode_response(response :: String.t()) :: {:ok, term()} | {:error, term()}
  def decode_response("+HI " <> rest) do
    rest
    |> trim_newline()
    |> Jason.decode()
  end

  def decode_response("+OK\r\n"), do: {:ok, "OK"}

  def decode_response("-ERR " <> rest), do: {:error, trim_newline(rest)}

  def trim_newline(str), do: String.trim_trailing(str, "\r\n")

  defp encode(command, args) do
    case Jason.encode(args) do
      {:ok, payload} -> {:ok, "#{command} #{payload}\r\n"}
      error -> error
    end
  end
end
