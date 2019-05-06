defmodule Mix.Tasks.JackCompiler do
    use Mix.Task
    require Logger

    def run([input_file | _]) do
      Application.ensure_all_started(:jack_compiler)

      StatelessJackCompiler.compile_file(input_file)
    end
end