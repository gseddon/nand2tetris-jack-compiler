defmodule StatelessJackCompiler do
  alias JackCompiler.CodeWriter
  require Logger

  def compile_file(path) do
    CodeWriter.set_file_name(path)
    {file_name, commands} = load_file(path)
    IO.puts("Loaded #{file_name}")
    dump_lines(commands)

    commands
    |> Enum.map(&tokenise/1)
    |> Enum.map(&CodeWriter.write_command/1)
  end

  def tokenise(command) do
    case command_type(command) do
      :arithmetic ->
        {:arithmetic, arg1(:arithmetic, command)}
      type when is_atom(type) ->
        {type, arg1(type, command), arg2(type, command)}
      other -> Process.exit(self(), "Haven't generated #{other} yet.")
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
      "push" <> _ -> :push
      "pop" <> _  -> :pop
      _           -> :arithmetic
    end
  end

  def arg1(type, command) do
    case type do
      :return ->
        Process.exit(self(), "Cannot call arg from a return type")
      :arithmetic ->
        command |> String.to_atom()
      _ ->
        String.split(command)
        |> Enum.at(1)
        |> String.to_atom()
    end
  end

  def arg2(type, command) do
    case type do
      _ ->
        String.split(command)
        |> Enum.at(2)
        |> String.to_integer()
    end
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