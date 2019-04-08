defmodule FaktoryWorker.Protocol do
  @moduledoc false

  @type protocol_command ::
          {:hello, args :: map()}
          | {:push, args :: map()}
          | {:beat, worker_id :: String.t()}
          | :info

  @type protocol_response ::
          {:ok, String.t()}
          | {:ok, map()}
          | {:ok, {:bulk_string, pos_integer()}}
          | {:error, any()}

  @spec encode_command(command :: protocol_command()) :: {:ok, String.t()} | {:error, term()}
  def encode_command({:hello, args}) do
    encode("HELLO", args)
  end

  def encode_command({:push, args}) do
    encode("PUSH", args)
  end

  def encode_command({:beat, worker_id}) do
    encode("BEAT", %{wid: worker_id})
  end

  def encode_command(:info) do
    encode("INFO")
  end

  @spec decode_response(response :: String.t()) :: protocol_response()
  def decode_response("+HI " <> rest) do
    decode(rest)
  end

  def decode_response("+OK\r\n"), do: {:ok, "OK"}

  def decode_response("-ERR " <> rest), do: {:error, trim_newline(rest)}

  def decode_response("$" <> rest) do
    length =
      rest
      |> trim_newline()
      |> String.to_integer()

    # we add '2' to length here to account for the newline '\r\n'
    # that will be at the end of the next server response
    {:ok, {:bulk_string, length + 2}}
  end

  def decode_response("+{" <> _ = response) do
    response
    |> String.trim_leading("+")
    |> decode()
  end

  def decode_response("{" <> _ = json_hash) do
    decode(json_hash)
  end

  defp trim_newline(str), do: String.trim_trailing(str, "\r\n")

  defp encode(command) do
    {:ok, "#{command}\r\n"}
  end

  defp encode(command, args) do
    case Jason.encode(args) do
      {:ok, payload} ->
        {:ok, "#{command} #{payload}\r\n"}

      {:error, _} ->
        {:error, "Invalid command args '#{inspect(args)}' given and could not be encoded"}
    end
  end

  defp decode(json_hash) do
    json_hash
    |> trim_newline()
    |> Jason.decode()
  end
end
