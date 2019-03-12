defmodule FaktoryWorker.Socket do
  @moduledoc false

  alias FaktoryWorker.Socket

  @enforce_keys [:host, :port, :socket]
  defstruct [:host, :port, :socket]

  @callback connect(host :: String.t(), port :: pos_integer()) ::
              {:ok, %Socket{}} | {:error, term()}
end
