defmodule JackCompiler.CodeWriter do
  use GenServer

  ## Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def set_file_name(file_path) do
    GenServer.call(__MODULE__, {:set_file_name, file_path})
  end

  def open_file(file_path) do
    GenServer.call(__MODULE__, {:initialise_file, {:file, file_path}})
  end

  def open_folder(folder_path) do
    GenServer.call(__MODULE__, {:initialise_file, {:folder, folder_path}})
  end

  def bootstrap() do
    [
      bootstrap: :the_system,
      call: {"Sys.init", 0}
    ]
    |> Enum.each(&write_command/1)
  end

  def write_command(command_tuple) do
    case GenServer.call(__MODULE__, command_tuple) do
      :ok ->
        :ok
      more_commands ->
        more_commands
        |> Enum.each(&write_command/1)
    end
  end

  # Server Callbacks
  @impl true
  def init(:ok) do
    {:ok, %{
      output_file: nil,
      file_name: nil,
      func: nil,
      symbol_count: 0
    }}
  end

  @impl true
  def handle_call({:initialise_file, file_path}, _, state) do
    {:ok, file} =
      file_path
      |> generate_output_filename()
      |> File.open([:write, :utf8])
    {:reply, :ok, %{state | output_file: file}}
  end

  @impl true
  def handle_call({:set_file_name, file_path}, _from, state) do
    file_name = Path.basename(file_path, ".vm")
    {:reply, :ok, %{state | file_name: file_name}}
  end

  @impl true
  def handle_call({:bootstrap, _}, _, state) do
    load_constant_to_location(256, "SP")
#    load_constant_to_location(32767, "LCL") ++
#    load_constant_to_location(32766, "ARG") ++
#    load_constant_to_location(32765, "THIS") ++
#    load_constant_to_location(32764, "THAT")
    |> write_commands(state)
  end

  @impl true
  def handle_call({:call, {function, nargs}}, _,
        state = %{file_name: fname, func: func, symbol_count: count}) do

    return_address = "#{fname}.caller.#{func}.#{count}.return"
    reply = [
      comment: "Calling #{function} with #{nargs} args.",
      raw_commands: [
        "@#{return_address}",
        "D=A"] ++
         push_d_to_stack(),
      push: "LCL",
      push: "ARG",
      push: "THIS",
      push: "THAT",
      raw_commands: ["""
       @#{nargs}
       D=A
       @SP
       D=M-D
       @5
       D=D-A
       M[ARG]=D // ARG = SP-n-5
       D=M[SP]
       M[LCL]=D // LCL = SP
       @#{function}
       0;JMP    // unconditionally jmp to #{function}
        (#{return_address})
      """]
    ]
    {:reply, reply, %{state | symbol_count: count + 1}}
  end

  @impl true
  def handle_call({:function, {function, nlocals}}, _, state) do
    reply =
      [
        comment: "function #{function} definition.",
        label: function,
        raw_commands:
          load_constant_to_location(nlocals, "R13"),
        label: "fn_defn_start_loop",
        raw_commands: [
          "@#{label_gen(function, "fn_defn_end_of_loop")}",
          "D;JEQ"],
        push: {:constant, 0},
        raw_commands: [
          "D=M[R13]",
          "D=D-1",
          "M[R13]=D"],
        goto: "fn_defn_start_loop",
        label: "fn_defn_end_of_loop"
      ]

    {:reply, reply, %{state | func: function}}
  end

  @impl true
  def handle_call({:comment, comment}, _, state) do
    comment = if String.starts_with?(comment, "//") do
      comment
    else
      "// " <> comment
    end
    ["#{comment}"] |> write_commands(state)
  end

  @impl true
  def handle_call({:return}, _, state = %{func: func}) do
    reply = [
      comment: "Return from #{func}",
      raw_commands:
      load_to_d_from_location("LCL") ++
      store_d_to_location("R13") ++ # FRAME = LCL

      load_to_d_from_ref_with_offset("R13", -5) ++
      store_d_to_location("R14") ++ # RET = *(FRAME-5)

      pop_to_d_from_stack() ++
      store_d_to_ref("ARG") ++ # *ARG = pop()

      load_to_d_from_location("ARG") ++
      ["D=D+1"] ++
      store_d_to_location("SP") ++ # SP = ARG+1

      load_to_d_from_ref_with_offset("R13", -1) ++
      store_d_to_location("THAT") ++ # THAT = *(FRAME-1)
      load_to_d_from_ref_with_offset("R13", -2) ++
      store_d_to_location("THIS") ++ # THIS = *(FRAME-2)
      load_to_d_from_ref_with_offset("R13", -3) ++
      store_d_to_location("ARG") ++ # ARG = *(FRAME-3)
      load_to_d_from_ref_with_offset("R13", -4) ++
      store_d_to_location("LCL") ++ # LCL = *(FRAME-4)

      ["A=M[R14]", "0;JMP"] # goto RET
    ]
    {:reply, reply, %{state | func: nil}}
  end


  @impl true
  def handle_call({:label, label}, _, state = %{func: func}) do
    ["(#{label_gen(func, label)})"] |> write_commands(state)
  end

  @impl true
  def handle_call({:goto, label}, _, state = %{func: func}) do
    ["""
    @#{label_gen(func, label)}
    0;JMP
    """]
    |> write_commands(state)
  end

  @impl true
  def handle_call({:if_goto, label}, _, state = %{func: func}) do
    pop_to_d_from_stack() ++
    ["""
     @#{label_gen(func, label)}
     D;JNE
     """] # remember -1 is "true" in Hack
    |> write_commands(state)
  end

  @impl true
  def handle_call({:if_false_goto, label}, _, state = %{func: func}) do
    pop_to_d_from_stack() ++
    ["""
    @#{func}$#{label}
    D;JEQ
    """] # this isn't part of the instruction set but I want it
    |> write_commands(state)
  end

  @impl true
  def handle_call({:arithmetic, operation}, _from, state) do
    ["// Performing arithmetic #{operation}"] ++
    case operation do
      op when op in [:add, :sub, :or, :and] ->
        perform_operation_on_two_stack_operands(op)

      op when op in [:neg, :not] ->
        perform_operation_on_one_stack_operand(op)

      cmp when cmp in [:gt, :lt, :eq]  ->
        compare_args_with(cmp, state)
    end
    |> write_commands(state)
  end


  @impl true
  def handle_call({:push, {segment, index}}, _from, state = %{file_name: fname}) do
    ["// Pushing #{segment} #{index}"] ++
    case segment do
      :constant ->
        load_constant_to_ref(index, "SP") ++ # load constant to where SP points
        increment_sp()

      segment when segment in [:local, :argument, :this, :that] ->
        ref =
          case segment do
            :local -> "LCL"
            :argument -> "ARG"
            :this -> "THIS"
            :that -> "THAT"
          end

        load_to_d_from_ref_with_offset(ref, index) ++
        push_d_to_stack()

      :temp ->
        ["D=M[#{index + 5}]"] ++
        push_d_to_stack()

      :pointer ->
        which =
         case index do
           0 -> "THIS"
           1 -> "THAT"
         end
        ["D=M[#{which}]"] ++
        push_d_to_stack()

      :static ->
      ["D=M[#{fname}.#{index}]"] ++
      push_d_to_stack()

    end
    |> write_commands(state)
  end

  @impl true
  def handle_call({:push, symbol}, _, state) do
    ["// Pushing symbol #{symbol}"] ++

    ["D=M[#{symbol}]"] ++
    push_d_to_stack()
    |> write_commands(state)
  end

  @impl true
  def handle_call({:pop, {segment, index}}, _from, state = %{file_name: fname}) do
    ["// Popping #{segment} #{index}"] ++
    case segment do
      segment when segment in [:local, :argument, :this, :that] ->
        ref =
          case segment do
            :local -> "LCL"
            :argument -> "ARG"
            :this -> "THIS"
            :that -> "THAT"
          end

        pop_to_d_from_stack() ++
        store_d_to_ref_with_offset(ref, index)

      :temp ->
        pop_to_d_from_stack() ++
        ["M[#{index + 5}]=D"]

      :pointer ->
        which =
          case index do
            0 -> "THIS"
            1 -> "THAT"
          end
        pop_to_d_from_stack() ++
        ["M[#{which}]=D"]

      :static ->
       pop_to_d_from_stack() ++
       ["M[#{fname}.#{index}]=D"]

    end
    |> write_commands(state)
  end

  @impl true
  def handle_call({:raw_commands, commands}, _, state) do
    commands
    |> write_commands(state)
  end
  # This is so I can be lazy with my piping into this. Hush you.
  # The commands will be written!
  def write_commands({_commands, _state} = r, __state), do: write_commands(r)
  def write_commands(commands, state), do: write_commands({commands, state})

  def write_commands({commands, state = %{output_file: file}}) do
    commands
    |> Enum.each(fn command -> IO.write(file, command <> "\n") end)
    {:reply, :ok, state}
  end

  def label_gen(nil, label), do: "#{label}"
  def label_gen(function, function), do: "#{function}"
  def label_gen(function, label), do: "#{function}$#{label}"

  def generate_output_filename({type, path}) do
    case type do
      :folder ->
        Path.join([
          path,
          Path.basename(path) <> ".asm"
        ])
      :file ->
        Path.join([
          Path.dirname(path),
          Path.basename(path, ".vm") <> ".asm"
        ])
    end
  end

  def perform_operation_on_one_stack_operand(op) do
    opstr =
      case op do
        :neg -> "-"
        :not -> "!"
      end

     decrement_sp() ++
     ["A=D",             # store newly decremented SP in A
      "M=#{opstr}M"] ++
     increment_sp()
  end

  def perform_operation_on_two_stack_operands(op) do
    opstr =
      case op do
        :sub -> "-"
        :add -> "+"
        :and -> "&"
        :or -> "|"
      end

   decrement_sp() ++
   move_from_ref("SP", "R13") ++  # store arg2 in R13
   pop_to_d_from_stack() ++       # load arg1 into D
   ["A=M[R13]",                   # load arg2 into A (from R13)
    "D=D#{opstr}A"] ++            # sub arg1 and arg2 into D
   push_d_to_stack()
  end

  def compare_args_with(cmp, state = %{file_name: fname, symbol_count: count}) do
    # Because we will probably have a bunch of these, salt the symbol name with
    # a random value every time
    salt = "#{fname}#{count}"

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

    {commands, %{state | symbol_count: count + 1}}
  end

  def pop_to_d_from_stack(), do:  decrement_sp() ++
                                   load_to_d_from_ref("SP")

  def push_d_to_stack(), do: store_d_to_ref("SP") ++
                             increment_sp()

  def load_constant_to_ref(from, to), do: ["@#{from}", "D=A","A=M[#{to}]", "M=D"]

  def load_constant_to_location(from, to), do: ["@#{from}", "D=A", "M[#{to}]=D"]

  def move_from_ref(from, to), do: ["A=M[#{from}]", "D=M", "@#{to}", "M=D"]

  def increment_sp(),  do:  ["D=M[SP]", "MD=D+1"]

  def decrement_sp(), do:  ["D=M[SP]", "MD=D-1"]

  def load_to_d_from_location(from), do: ["D=M[#{from}]"]

  def load_to_d_from_ref(from), do: ["A=M[#{from}]", "D=M"]

  def load_to_d_from_ref_with_offset(from, offset) do
    op = if offset < 0, do: "-", else: "+"
    offset = abs(offset)
    [
      "@#{offset}",
      "D=A",
      "A=M[#{from}]",
      "A=A#{op}D",     # calculate ref + offset
      "D=M"
    ]
  end

  def store_d_to_location(to), do: ["M[#{to}]=D"]

  def store_d_to_ref(to), do: ["A=M[#{to}]", "M=D"]

  def store_d_to_ref_with_offset(to, offset) do
    [
      "M[R13]=D",   # save D in R13
      "@#{offset}",
      "D=A",
      "A=M[#{to}]",
      "D=A+D",
      "M[R14]=D",  # calculate ref + offset and store in R14
      "D=M[R13]",  # load D back from R13
      "A=M[R14]",  # load ref + offset into A
      "M=D"        # store original D into reference!
    ]
  end

end