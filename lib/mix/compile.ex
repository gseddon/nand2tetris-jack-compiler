defmodule Mix.Tasks.JackCompiler do
    use Mix.Task

    alias JackCompiler.Parser

    def run([input_file | _]) do
      Application.ensure_all_started(:jack_compiler)
      :lol = Parser.hello(input_file)
    end
end