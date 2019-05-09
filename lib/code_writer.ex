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
    {:ok, %{
      output_file: nil,
      file_name: nil,
      static_count: 0
    }}
  end

  @impl true
  def handle_call({:set_file_name, file_path}, _from, state) do
    {:ok, file} =
     file_path
     |> generate_output_filename()
     |> File.open([:write, :utf8])

     file_name = Path.basename(file_path, ".vm")
    {:reply, :ok, %{state |
      output_file: file,
      file_name: file_name
    }}
  end

  @impl true
  def handle_call({:arithmetic, operation},
        _from,
        state ) do

    case operation do
      :add ->  {decrement_sp() ++
               move_from_ref("SP", "R13") ++  # store arg2 in R13
               pop_to_d_from_stack() ++       # load arg1 into D
              ["A=M[R13]",                    # load arg2 into A (from R13)
               "D=A+D"] ++                    # add arg1 and arg2 into D
               push_d_to_stack(), state}

      :sub -> {decrement_sp() ++
              move_from_ref("SP", "R13") ++  # store arg2 in R13
              pop_to_d_from_stack() ++       # load arg1 into D
              ["A=M[R13]",                   # load arg2 into A (from R13)
               "D=D-A"] ++                   # sub arg1 and arg2 into D
              push_d_to_stack(), state}

      :or ->  {decrement_sp() ++
              move_from_ref("SP", "R13") ++  # store arg2 in R13
              pop_to_d_from_stack() ++       # load arg1 into D
              ["A=M[R13]",                   # load arg2 into A (from R13)
               "D=A|D"] ++                   # or arg1 and arg2 into D
              push_d_to_stack(), state}

      :and -> {decrement_sp() ++
              move_from_ref("SP", "R13") ++  # store arg2 in R13
              pop_to_d_from_stack() ++       # load arg1 into D
              ["A=M[R13]",                   # load arg2 into A (from R13)
               "D=A&D"] ++                   # and arg1 and arg2 into D
              push_d_to_stack(), state}

      :neg -> {decrement_sp() ++
              ["A=D",             # store newly decremented SP in A
               "M=-M"] ++
              increment_sp(), state}

      :not ->{decrement_sp() ++
              ["A=D",             # store newly decremented SP in A
               "M=!M"] ++
              increment_sp(), state}

      cmp when cmp in [:gt, :lt, :eq]  ->
        compare_args_with(cmp, state)


      op -> Process.exit(self(), "Operation #{op} not defined.")
    end
    |> write_commands()
  end

  @impl true
  def handle_call({:push, segment, index}, _from, state) do
    case segment do
      :constant -> {load_constant_to_ref(index, "SP") ++ # load constant to where SP points
                   increment_sp(), state}

      seg -> Process.exit(self(), "Segment #{seg} not defined.")
    end
    |> write_commands()
  end

  def write_commands({commands, state = %{output_file: file}}) do
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

  def compare_args_with(cmp, state = %{file_name: fname, static_count: static}) do
    # Because we will probably have a bunch of these, salt the symbol name with
    # a random value every time
    salt = "#{fname}#{static}"


    # if our stack is like x | y | SP
    # gt is true if x > y
    # a.k.a. arg2 < arg1
    cmpstr =
      cmp
      |> Atom.to_string()
      |> String.upcase()

    commands =
     decrement_sp() ++
     move_from_ref("SP", "R13") ++  # store arg2 in R13
     pop_to_d_from_stack() ++       # load arg1 into D
     ["""
     A=M[R13] // load arg2 into A (from R13)
     D=D-A    // arg1 - arg2. If positive, arg1 > arg2. jump to true.
     @TRUE#{salt}
     D;J#{cmpstr}
     A=M[SP]
     M=0      // false
     @END#{salt}
     0;JMP
     (TRUE#{salt})
     A=M[SP]
     M=-1     // true
     (END#{salt})
     """
     ] ++
     increment_sp()

    {commands, %{state | static_count: static + 1}}
  end

  def pop_to_d_from_stack(), do:  decrement_sp() ++
                                   load_to_d_from_ref("SP")

  def push_d_to_stack(), do: store_d_to_ref("SP") ++
                             increment_sp()

  def load_constant_to_ref(from, to), do: ["@#{from}", "D=A","A=M[#{to}]", "M=D"]

  def move_from_ref(from, to), do: ["A=M[#{from}]", "D=M", "@#{to}", "M=D"]

  def increment_sp(),  do:  ["D=M[SP]", "MD=D+1"]

  def decrement_sp(), do:  ["D=M[SP]", "MD=D-1"]

  def load_to_d_from_ref(from), do: ["A=M[#{from}]", "D=M"]

  def store_d_to_ref(to), do: ["A=M[#{to}]", "M=D"]

end