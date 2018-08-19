defmodule SzivexHardware do
  @moduledoc """
  Documentation for SzivexHardware.
  """
  def start(_type, _args) do
    SzivexHardware.Supervisor.start_link([])
  end
end
