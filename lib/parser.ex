
defmodule JackCompiler.Parser do
  use GenServer

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def hello(server \\ __MODULE__, greeting) do
    GenServer.call(server, {:hello, greeting})
  end

  @doc """
  Ensures there is a bucket associated with the given `name` in `server`.
  """
  def create(server, name) do
    GenServer.cast(server, {:create, name})
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:hello, greeting}, _from, state) do
    IO.puts("Hello from Parser. #{greeting}")
    {:reply, :lol, state}
  end

end