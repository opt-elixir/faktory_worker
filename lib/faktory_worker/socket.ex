defmodule FaktoryWorker.Socket do
  @moduledoc false

  alias FaktoryWorker.Connection

  @callback connect(host :: String.t(), port :: pos_integer()) ::
              {:ok, Connection.t()} | {:error, term()}

  @callback send(connection :: Connection.t(), payload :: String.t()) ::
              :ok | {:error, term()}

  @callback recv(connection :: Connection.t()) :: {:ok, String.t()} | {:error, term()}
end
