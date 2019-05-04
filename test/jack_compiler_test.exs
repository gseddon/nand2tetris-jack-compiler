defmodule JackCompilerTest do
  use ExUnit.Case
  doctest JackCompiler

  test "greets the world" do
    assert JackCompiler.hello() == :world
  end
end
