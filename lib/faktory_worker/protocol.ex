defmodule FaktoryWorker.Protocol do
  @moduledoc false

  @type protocol_command :: {:hello, pos_integer()}

  @spec encode_command(command :: protocol_command()) :: {:ok, String.t()} | {:error, term()}
  def encode_command({:hello, version}) when is_integer(version) and version > 0 do
    case Jason.encode(%{v: version}) do
      {:ok, payload} -> {:ok, "HELLO #{payload}\r\n"}
      error -> error
    end
  end

  @spec decode_response(response :: String.t()) :: {:ok, term()} | {:error, term()}
  def decode_response("+HI " <> rest) do
    rest
    |> String.trim_trailing("\r\n")
    |> Jason.decode()
  end

  def decode_response("+OK\r\n"), do: {:ok, "OK"}
end
