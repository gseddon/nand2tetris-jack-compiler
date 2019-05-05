defmodule Mix.Tasks.JackCompiler do
    use Mix.Task
    require Logger

    alias JackCompiler.Parser

    def run([input_file | _]) do
      Application.ensure_all_started(:jack_compiler)
      {file_name, line_count} = Parser.load_file(input_file)
      Logger.info("Loaded #{file_name} with #{line_count} lines.")
      Parser.dump_lines(file_name)
    end
end