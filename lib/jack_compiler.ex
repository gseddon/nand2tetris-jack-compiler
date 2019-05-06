defmodule JackCompiler do
  use Application

  def start(_type, _args) do
    JackCompiler.Supervisor.start_link(name: JackCompiler.Supervisor)
  end
end

defmodule JackCompiler.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      JackCompiler.CodeWriter
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end