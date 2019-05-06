defmodule JackCompiler.CodeWriter do
  use GenServer

  ## Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  def set_file_name(file_path) do
    GenServer.call(__MODULE__, {:set_file_name, file_path})
  end

  def write_command(command_tuple) do
    GenServer.call(__MODULE__, command_tuple)
  end

  # Server Callbacks
  @impl true
  def init(:ok) do
    {:ok, %{output_file: nil}}
  end

  @impl true
  def handle_call({:set_file_name, file_path}, _from, state) do
    {:ok, file} =
     file_path
     |> generate_output_filename()
     |> File.open([:write, :utf8])
    {:reply, :ok, %{state | output_file: file}}
  end

  @impl true
  def handle_call({:arithmetic, operation}, _from, state) do
    case operation do
      "add" -> decrement_sp() ++
               move_from_ref("SP", "R13") ++  # store arg2 in R13
               decrement_sp() ++
               load_to_d_from_ref("SP") ++    # load arg1 into D
            [  "@R13",
               "A=M",                         # load arg2 into A (from R13)
               "D=A+D"] ++                    # add arg1 and arg2 into D
              store_d_to_ref("SP") ++         # store result at SP location
              increment_sp()

      op -> Process.exit(self(), "Operation #{op} not defined.")
    end
    |> write_commands(state)
  end

  @impl true
  def handle_call({:push, segment, index}, _from, state) do
    case segment do
      :constant -> load_constant_to_ref(index, "SP") ++ # load constant to where SP points
                   increment_sp()

      seg -> Process.exit(self(), "Segment #{seg} not defined.")
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
      Path.dirname(file_path),
      Path.basename(file_path, ".vm") <> ".asm"
    ])
  end

  def load_constant_to_ref(from, to), do: ["@#{from}", "D=A","A=M[#{to}]", "M=D"]

  def move_from_ref(from, to), do: ["A=M[#{from}]", "D=M", "@#{to}", "M=D"]

  def increment_sp(),  do:  ["D=M[SP]", "MD=D+1"]

  def decrement_sp(), do:  ["D=M[SP]", "MD=D-1"]

  def load_to_d_from_ref(from), do: ["A=M[#{from}]", "D=M"]

  def store_d_to_ref(to), do: ["A=M[#{to}]", "M=D"]

end