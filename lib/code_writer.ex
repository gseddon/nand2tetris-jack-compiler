defmodule JackCompiler.CodeWriter do
  use GenServer

  ## Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  def set_file_name(file_name) do

  end

  # Server Callbacks
  @impl true
  def init(:ok) do
    {:ok, output_file: nil}
  end

end