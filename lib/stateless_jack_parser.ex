defmodule StatelessJackCompiler do
  alias JackCompiler.CodeWriter
  require Logger

  def compile_file(path) do
    CodeWriter.set_file_name(path)
    {file_name, commands} = load_file(path)
    IO.puts("Loaded #{file_name}")
#    dump_lines(commands)
#    CodeWriter.bootstrap()
    commands
    |> Enum.map(&tokenise/1)
    |> Enum.each(&CodeWriter.write_command/1)
  end

  def tokenise(command) do
    case command_type(command) do
      :arithmetic ->
        {:arithmetic, command |> String.to_atom()}

      type when type in [:label, :goto, :if_goto] ->
        {type, arg1label(command)}

      type when type in [:function, :call] ->
        {type, {arg1label(command), arg2(command)}}

      type when type in [:push, :pop]->
        {type, {arg1(command), arg2(command)}}

      :return ->
        {:return}
    end
  end

  def load_file(path) do
    {:ok, file} = File.open(path, [:read, :utf8] )
    file_name = extract_vm_filename(path)

    lines = Enum.flat_map(IO.stream(file, :line), &clean_line/1)
    {file_name, lines}
  end

  def dump_lines(lines) do
    lines
    |> Enum.join("\n")
    |> IO.puts()
  end

  def command_type(command) do
    case command do
      "push" <> _   -> :push
      "pop" <> _    -> :pop
      "label" <> _  -> :label
      "call" <> _   -> :call
      "return" <> _ -> :return
      "function"<>_ -> :function
      "goto" <> _   -> :goto
      "if-goto" <>_ -> :if_goto
      _             -> :arithmetic
    end
  end

  def arg1label(command) do
    String.split(command)
    |> Enum.at(1)
  end

  def arg1(command) do
    String.split(command)
    |> Enum.at(1)
    |> String.to_atom()
  end

  def arg2(command) do
    String.split(command)
    |> Enum.at(2)
    |> String.to_integer()
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