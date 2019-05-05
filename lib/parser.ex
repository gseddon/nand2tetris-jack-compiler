
defmodule JackCompiler.Parser do
  use GenServer

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def load_file(file) do
    GenServer.call(__MODULE__, {:load, file})
  end

  def dump_lines(file_name) do
    GenServer.call(__MODULE__, {:print, file_name})
  end

  def has_more_commands?() do
    GenServer.call(__MODULE__, {:has_more_commands})
  end

  def advance() do
    GenServer.call(__MODULE__, {:advance})
  end

  def command_type() do
    GenServer.call(__MODULE__, {:command_type})
  end

  def arg1() do
    GenServer.call(__MODULE__, {:arg, 1})
  end

  def arg2() do
    GenServer.call(__MODULE__, {:arg, 2})
  end

  ## Server Callbacks
  @impl true
  def init(:ok) do
    {:ok, %{
      current_file: nil,
      current_command: nil,
      command_type: nil
    }}
  end

  @impl true
  def handle_call({:load, file_path}, _from, state) do
    {:ok, file} = File.open(file_path, [:read, :utf8] )
    file_name = extract_vm_filename(file_path)

    lines = Enum.flat_map(IO.stream(file, :line), &clean_line/1)
    state = state
    |> Map.put(file_name, lines)
    |> Map.put(:current_file, lines)
    {:reply, {file_name, Kernel.length(lines)}, state}
  end

  @impl true
  def handle_call({:print, file_name}, _from, state) do
    state
    |> Map.get(file_name)
    |> Enum.join("\n")
    |> IO.puts()
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:has_more_commands}, _from, state = %{current_file: file}) do
    {:reply, not Enum.empty?(file), state}
  end

  @impl true
  def handle_call({:advance}, _from, state = %{current_file: [next | tl]}) do
    state = state
      |> Map.put(:current_file, tl)
      |> Map.put(:current_command, next)
    {:reply, next, state}
  end

  @impl true
  def handle_call({:command_type}, _from, state = %{current_command: command}) do
    type =
      case command do
        "push" <> _ -> :push
        "pop" <> _  -> :pop
        _           -> :arithmetic
      end
    {:reply, type, %{state | command_type: type}}
  end

  @impl true
  def handle_call({:arg, n}, _from, state = %{current_command: command, command_type: type}) do
    arg =
      case type do
        :return ->
          Process.exit("Cannot call arg from a return type")
        :arithmetic when n == 1 ->
          command
        _ ->
          String.split(command) |> Enum.at(n)
      end
    {:reply, arg, state}
  end

  defp clean_line(line) do
    line
    |> String.split("//")
    |> hd()
    |> String.trim()
    |> (fn
          "" -> []
          command -> [command]
    end).()
  end


  defp is_vm_dir?(file_path) do
    extract_vm_filename(file_path) == Path.basename(file_path)
  end

  defp extract_vm_filename(file_path), do: Path.basename(file_path, ".vm")

end