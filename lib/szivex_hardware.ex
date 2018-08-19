defmodule SzivexHardware do
  @moduledoc """
  Documentation for SzivexHardware.
  """
  def start(_type, _args) do
  	IO.write("Starting SzivexHardware, waiting 30sec for inputs to stabilise...")
  	Process.sleep(10000)
  	IO.puts("done.")
    SzivexHardware.Supervisor.start_link([])
  end
end
