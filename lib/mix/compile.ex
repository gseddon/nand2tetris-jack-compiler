defmodule Mix.Tasks.JackCompiler do
    use Mix.Task
    require Logger

    def run([input_path | _]) do
      Application.ensure_all_started(:jack_compiler)
      StatelessJackCompiler.init(input_path)
    end
end