defmodule JackCompiler.CodeWriter do
  use GenServer

  ## Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  def set_file_name(file_path) do
    GenServer.call(__MODULE__, {:set_file_name, file_path})
  end

#  @doc"""
#    Writes the assembly code that is the translation of the given arithmetic command.
#  """
#  def write_arithmetic(command) do
#    GenServer.call(__MODULE__, {:write, command})
#  end
#
#  @doc """
#    Writes the assembly code that is the translation of the given command,
#    where command is either C_PUSH or C_POP.
#  """
#  @spec write_push_pop(:push | :pop, string, integer) :: :ok
#  def write_push_pop(command, segment, index) do
#    GenServer.call(__MODULE__, {command, segment, index})
#  end

  def write_command(command_tuple) do
    GenServer.call(__MODULE__, command_tuple)
  end

  # Server Callbacks
  @impl true
  def init(:ok) do
    {:ok, output_file: nil}
  end

  def handle_call({:set_file_name, file_path}, _from, state) do
    {:ok, file} =
     file_path
     |> generate_output_filename()
     |> File.open([:write, :utf8])
    {:reply, :ok, %{state | output_file: file}}
  end

  def handle_call({:arithmetic, operation}, _from, state) do
    case operation do
      "add" -> move("SP", "R13") ++  # store arg2 in R13
              decrement_sp() ++
              load_to_d("SP") ++    # load arg1 into D
            [  "@R13",
               "A=M",               # load arg2 into A
               "D=A+D"] ++          # add arg1 and arg2 into D
              store_d_to("SP")      # store result at SP location
      op -> Process.exit("Operation #{op} not defined.")
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
      seg -> Process.exit("Segment #{seg} not defined.")
    end
    |> write_commands(state)
  end

  def write_commands(commands, state = %{output_file: file}) do
    commands
    |> Enum.each(fn command -> IO.write(file, command <> "\n") end)
    {:reply, :ok, state}
  end

  def generate_output_filename(file_path) do
    Path.join([
      Path.dir(file_path),
      Path.basename(file_path) <> ".asm"
    ])
  end

  def move(from, to), do: ["@#{from}", "D=M", "@#{to}", "M=D"]

  def increment_sp(),  do:  ["@SP", "D=M", "MD=D+1"]

  def decrement_sp(), do:  ["@SP", "D=M", "MD=D-1"]

  def load_to_d(from), do: ["@#{from}", "D=M"]

  def store_d_to(to), do: ["@#{to}", "M=D"]

end