defmodule JackCompiler.CodeWriter do
  use GenServer

  ## Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  def set_file_name(file_path) do
    GenServer.call(__MODULE__, {:set_file_name, file_path})
  end

  @doc"""
    Writes the assembly code that is the translation of the given arithmetic command.
  """
  def write_arithmetic(command) do
    GenServer.call(__MODULE__, {:write, command})
  end

  @doc """
    Writes the assembly code that is the translation of the given command,
    where command is either C_PUSH or C_POP.
  """
  @spec write_push_pop(:push | :pop, string, integer) :: :ok
  def write_push_pop(command, segment, index) do
    GenServer.call(__MODULE__, {command, segment, index})
  end

  # Server Callbacks
  @impl true
  def init(:ok) do
    {:ok, output_file: nil}
  end

  def handle_call({:set_file_name, file_path}, _from, state) do
    {:ok, file} = File.open(file_path, [:write, :utf8] )
    {:reply, :ok, %{state | output_file: file}}
  end

  def handle_call({:arithmetic, operation}, _from, state) do
    case operation do
      :add -> ["D=M[SP] ",       # load stack pointer
               "M[R13]=D"   ] ++ # store arg2 in R13
               decrement_sp() ++
            [  "D=M[SP] ",       # load arg1 into D
               "A=M[R13]",       # load arg2 into A
               "D=A+D   ",       # add arg1 and arg2 into D
               "M[SP]=D " ]      # store result at SP location
    end
    |> write_commands(state)
  end

  def handle_call({:push, segment, index}, _from, state) do
    case segment do
      :constant ->   increment_sp() ++ [
                     "@#{index}", # load the constant into A
                     "D=A",       # move the constant into D
                     "M[SP]=D",   # load the constant into where the SP is
                   ]
    end
    |> write_commands(state)
  end

  def write_commands(commands, state = %{output_file: file}) do
    commands
    |> Enum.each(fn command -> IO.write(file, command <> "\n") end)
    {:reply, :ok, state}
  end

  def increment_sp(),  do:  ["D=M[SP]", "MD=D+1"]
  def deccrement_sp(), do:  ["D=M[SP]", "MD=D-1"]

end