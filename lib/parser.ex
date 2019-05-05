
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

  ## Server Callbacks
  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:load, file_path}, _from, state) do
    {:ok, file} = File.open(file_path, [:read, :utf8] )
    file_name = extract_vm_filename(file_path)

    lines = Enum.flat_map(IO.stream(file, :line), &clean_line/1)
    state = Map.put(state, file_name, lines)
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