defmodule FaktoryWorker.Socket do
  @moduledoc false

  alias FaktoryWorker.Connection

  @callback connect(host :: String.t(), port :: pos_integer()) ::
              {:ok, %Connection{}} | {:error, term()}

  @callback send(connection :: %Connection{}, payload :: String.t()) ::
              :ok | {:error, term()}

  @callback recv(connection :: %Connection{}) :: {:ok, String.t()} | {:error, term()}
end
