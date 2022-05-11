defmodule FaktoryWorker.Protocol do
  @moduledoc false

  @type protocol_command ::
          {:hello, args :: map()}
          | {:push, args :: map()}
          | {:batch_new, args :: map()}
          | {:batch_commit, batch_id :: String.t()}
          | {:batch_status, batch_id :: String.t()}
          | {:batch_open, batch_id :: String.t()}
          | {:beat, process_wid :: String.t()}
          | {:fetch, queues :: [String.t()]}
          | {:ack, job_id :: String.t()}
          | {:fail, args :: map()}
          | {:mutate, args :: map()}
          | {:track_get, job_id :: String.t()}
          | {:track_set, args :: map()}
          | :info
          | :end
          | :flush

  @type protocol_response ::
          {:ok, String.t()}
          | {:ok, map()}
          | {:ok, {:bulk_string, pos_integer()}}
          | {:ok, :no_content}
          | {:error, any()}

  @spec encode_command(command :: protocol_command()) :: {:ok, String.t()} | {:error, term()}
  def encode_command({:hello, args}) do
    encode("HELLO", args)
  end

  def encode_command({:push, args}) do
    encode("PUSH", args)
  end

  def encode_command({:batch_new, args}) do
    encode("BATCH NEW", args)
  end

  def encode_command({:batch_commit, batch_id}) do
    encode("BATCH COMMIT", batch_id)
  end

  def encode_command({:batch_status, batch_id}) do
    encode("BATCH STATUS", batch_id)
  end

  def encode_command({:batch_open, batch_id}) do
    encode("BATCH OPEN", batch_id)
  end

  def encode_command({:beat, process_wid}) do
    encode("BEAT", %{wid: process_wid})
  end

  def encode_command({:fetch, []}) do
    encode("FETCH", "default")
  end

  def encode_command({:fetch, queues}) do
    encode("FETCH", Enum.join(queues, " "))
  end

  def encode_command({:ack, job_id}) do
    encode("ACK", %{jid: job_id})
  end

  def encode_command({:fail, args}) do
    encode("FAIL", args)
  end

  def encode_command({:mutate, args}) do
    encode("MUTATE", args)
  end

  def encode_command({:track_get, job_id}) do
    encode("TRACK GET", job_id)
  end

  def encode_command({:track_set, args}) do
    encode("TRACK SET", args)
  end

  def encode_command(:info) do
    encode("INFO")
  end

  def encode_command(:end) do
    encode("END")
  end

  def encode_command(:flush) do
    encode("FLUSH")
  end

  def encode_command(command) do
    raise "invalid command: unable to encode `#{inspect(command)}`"
  end

  @spec decode_response(response :: String.t()) :: protocol_response()
  def decode_response("+HI " <> rest), do: decode(rest)

  def decode_response("+OK\r\n"), do: {:ok, "OK"}

  def decode_response("-ERR " <> rest), do: {:error, trim_newline(rest)}

  def decode_response("-SHUTDOWN " <> rest), do: {:error, trim_newline(rest)}

  def decode_response("-NOTUNIQUE " <> _), do: {:error, :not_unique}

  def decode_response("$-1\r\n"), do: {:ok, :no_content}

  def decode_response("$" <> rest) do
    length =
      rest
      |> trim_newline()
      |> String.to_integer()

    # we add '2' to length here to account for the newline '\r\n'
    # that will be at the end of the next server response
    {:ok, {:bulk_string, length + 2}}
  end

  def decode_response("b-" <> _ = response), do: {:ok, trim_newline(response)}

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

  defp encode(command, args) when is_binary(args) do
    {:ok, "#{command} #{args}\r\n"}
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
